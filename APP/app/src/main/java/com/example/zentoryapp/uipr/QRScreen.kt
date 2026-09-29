package com.example.zentoryapp.uipr

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import android.view.LayoutInflater
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.QrActivityBinding
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import okhttp3.*
import org.json.JSONObject
import java.io.IOException
import java.net.URLEncoder
import java.util.concurrent.Executors

@OptIn(ExperimentalGetImage::class)
@Composable 
fun QRScreen(navController: NavController) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }
    val client = remember { OkHttpClient() }
    var isScanning by remember { mutableStateOf(true) }
    
    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
        onResult = { granted ->
            hasCameraPermission = granted
            if (!granted) {
                Toast.makeText(context, "Permiso de cámara denegado", Toast.LENGTH_SHORT).show()
            }
        }
    )

    LaunchedEffect(Unit) {
        if (!hasCameraPermission) {
            launcher.launch(Manifest.permission.CAMERA)
        }
    }

    fun fetchProductInfo(barcode: String) {
        if (!isScanning) return
        isScanning = false

        val url = "https://world.openfoodfacts.org/api/v0/product/$barcode.json"
        val request = Request.Builder().url(url).build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                (context as? android.app.Activity)?.runOnUiThread {
                    Toast.makeText(context, "Error de red: ${e.message}", Toast.LENGTH_SHORT).show()
                    isScanning = true
                }
            }

            override fun onResponse(call: Call, response: Response) {
                val body = response.body?.string()
                (context as? android.app.Activity)?.runOnUiThread {
                    if (response.isSuccessful && body != null) {
                        val json = JSONObject(body)
                        if (json.optInt("status") == 1) {
                            val product = json.getJSONObject("product")
                            val name = product.optString("product_name", "Producto Desconocido")
                            val category = product.optString("categories", "").split(",").firstOrNull() ?: "Otros"
                            val brand = product.optString("brands", "N/A")
                            val quantity = product.optString("quantity", "N/A")

                            val route = "add_product?qrNombre=${URLEncoder.encode(name, "UTF-8")}" +
                                    "&qrCategoria=${URLEncoder.encode(category, "UTF-8")}" +
                                    "&qrMarca=${URLEncoder.encode(brand, "UTF-8")}" +
                                    "&qrPresentacion=${URLEncoder.encode(quantity, "UTF-8")}"
                            
                            navController.navigate(route)
                        } else {
                            Toast.makeText(context, "No se encontró información del producto", Toast.LENGTH_LONG).show()
                            isScanning = true
                        }
                    } else {
                        Toast.makeText(context, "Error al obtener datos", Toast.LENGTH_SHORT).show()
                        isScanning = true
                    }
                }
            }
        })
    }

    if (hasCameraPermission) {
        AndroidView(
            modifier = Modifier.fillMaxSize(), 
            factory = { ctx -> 
                val b = QrActivityBinding.inflate(LayoutInflater.from(ctx))
                
                val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                cameraProviderFuture.addListener({
                    val cameraProvider = cameraProviderFuture.get()
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(b.viewFinder.surfaceProvider)
                    }

                    val scanner = BarcodeScanning.getClient()
                    val imageAnalysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()

                    imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                        val mediaImage = imageProxy.image
                        if (mediaImage != null) {
                            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                            scanner.process(image)
                                .addOnSuccessListener { barcodes ->
                                    for (barcode in barcodes) {
                                        barcode.rawValue?.let { fetchProductInfo(it) }
                                    }
                                }
                                .addOnFailureListener { Log.e("QRScreen", "Scan failed", it) }
                                .addOnCompleteListener { imageProxy.close() }
                        } else {
                            imageProxy.close()
                        }
                    }

                    try {
                        cameraProvider.unbindAll()
                        val camera = cameraProvider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageAnalysis)
                        
                        var isFlashOn = false
                        b.linterna.setOnClickListener {
                            if (camera.cameraInfo.hasFlashUnit()) {
                                isFlashOn = !isFlashOn
                                camera.cameraControl.enableTorch(isFlashOn)
                                b.linterna.text = if (isFlashOn) "Apagar" else "Linterna"
                            } else {
                                Toast.makeText(ctx, "La linterna no está disponible", Toast.LENGTH_SHORT).show()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("QRScreen", "Use case binding failed", e)
                    }
                }, ContextCompat.getMainExecutor(ctx))

                b.bottomNavigationView.selectedItemId = R.id.nav_escanear
                b.bottomNavigationView.setOnItemSelectedListener { 
                    when (it.itemId) { 
                        R.id.nav_home -> { navController.navigate("home"); true }
                        R.id.nav_productos -> { navController.navigate("productos"); true }
                        R.id.nav_calendario -> { navController.navigate("calendar"); true }
                        else -> true 
                    } 
                }
                b.root 
            }
        )
    } else {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(text = "Se requiere permiso de cámara", color = Color.White)
        }
    }
}
