package com.example.zentoryapp.uipr

import android.app.DatePickerDialog
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.widget.PopupMenu
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.ItemCatalogoBinding
import com.example.zentoryapp.databinding.RegistrarproductoActivityBinding
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Calendar

@Composable
fun RegistrarProductoScreen(
    navController: NavController,
    productId: String? = null,
    qrNombre: String? = null,
    qrCategoria: String? = null,
    qrMarca: String? = null,
    qrPresentacion: String? = null
) {
    val context = LocalContext.current
    val db = remember { FirebaseFirestore.getInstance() }
    val auth = remember { FirebaseAuth.getInstance() }
    
    var productName by remember { mutableStateOf(qrNombre ?: "") }
    var category by remember { mutableStateOf(qrCategoria ?: "Selecciona una categoría") }
    var brand by remember { mutableStateOf(qrMarca ?: "") }
    var presentation by remember { mutableStateOf(qrPresentacion ?: "") }
    var quantity by remember { mutableStateOf("") }
    var expiryDate by remember { mutableStateOf("Selecciona la fecha") }
    var initialImageBase64 by remember { mutableStateOf<String?>(null) }
    
    var selectedBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var isDataLoaded by remember { mutableStateOf(false) }
    var currentStoreId by remember { mutableStateOf<String?>(null) }
    var catalogList by remember { mutableStateOf<List<Map<String, Any>>>(emptyList()) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (!isGranted) {
            Toast.makeText(context, "Las notificaciones están desactivadas. No recibirás alertas de vencimiento.", Toast.LENGTH_LONG).show()
        }
    }

    LaunchedEffect(Unit) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    LaunchedEffect(currentStoreId) {
        val sid = currentStoreId ?: return@LaunchedEffect
        db.collection("tiendas").document(sid).collection("catalogo").get().addOnSuccessListener { res ->
            catalogList = res.documents.mapNotNull { it.data }
        }
    }

    LaunchedEffect(auth.currentUser) {
        val uid = auth.currentUser?.uid ?: return@LaunchedEffect
        db.collection("usuarios").document(uid).get().addOnSuccessListener { userDoc ->
            val userTiendaId = userDoc.getString("tiendaId")
            
            if (userTiendaId != null) {
                currentStoreId = userTiendaId
                loadProductData(db, userTiendaId, productId) { data ->
                    if (data != null) {
                        productName = data["nombre"] as? String ?: ""
                        category = data["categoria"] as? String ?: "Selecciona una categoría"
                        brand = data["marca"] as? String ?: ""
                        presentation = data["presentacion"] as? String ?: ""
                        quantity = data["cantidad"] as? String ?: ""
                        expiryDate = data["fechaVencimiento"] as? String ?: "Selecciona la fecha"
                        initialImageBase64 = data["imagen"] as? String
                    }
                    isDataLoaded = true
                }
            } else {
                // Fallback para usuarios que no tienen el campo marcado
                db.collection("tiendas").whereEqualTo("adminUidReal", uid).get().addOnSuccessListener { adminRes ->
                    if (!adminRes.isEmpty) {
                        currentStoreId = adminRes.documents[0].id
                        loadProductData(db, currentStoreId, productId) { data ->
                            if (data != null) {
                                productName = data["nombre"] as? String ?: ""
                                category = data["categoria"] as? String ?: "Selecciona una categoría"
                                brand = data["marca"] as? String ?: ""
                                presentation = data["presentacion"] as? String ?: ""
                                quantity = data["cantidad"] as? String ?: ""
                                expiryDate = data["fechaVencimiento"] as? String ?: "Selecciona la fecha"
                                initialImageBase64 = data["imagen"] as? String
                            }
                            isDataLoaded = true
                        }
                    } else {
                        db.collectionGroup("personal").whereEqualTo("uid", uid).get().addOnSuccessListener { workerRes ->
                            if (!workerRes.isEmpty) {
                                currentStoreId = workerRes.documents[0].reference.parent.parent?.id
                                loadProductData(db, currentStoreId, productId) { data ->
                                    if (data != null) {
                                        productName = data["nombre"] as? String ?: ""
                                        category = data["categoria"] as? String ?: "Selecciona una categoría"
                                        brand = data["marca"] as? String ?: ""
                                        presentation = data["presentacion"] as? String ?: ""
                                        quantity = data["cantidad"] as? String ?: ""
                                        expiryDate = data["fechaVencimiento"] as? String ?: "Selecciona la fecha"
                                        initialImageBase64 = data["imagen"] as? String
                                    }
                                    isDataLoaded = true
                                }
                            } else {
                                Toast.makeText(context, "No tienes una tienda vinculada", Toast.LENGTH_SHORT).show()
                                navController.popBackStack()
                            }
                        }
                    }
                }
            }
        }
    }

    if (!isDataLoaded) return

    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { if (it != null) { selectedBitmap = it; selectedUri = null; initialImageBase64 = null } }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { if (it != null) { selectedUri = it; selectedBitmap = null; initialImageBase64 = null } }

    val inflater = remember { LayoutInflater.from(context) }

    AndroidView(modifier = Modifier.fillMaxSize(), factory = { ctx ->
        val b = RegistrarproductoActivityBinding.inflate(inflater)
        
        b.etNombreProducto.setText(productName)
        b.etMarca.setText(brand)
        b.etPresentacion.setText(presentation)
        b.etCantidad.setText(quantity)
        b.tvCategoria.text = category
        if (category != "Selecciona una categoría") b.tvCategoria.setTextColor(Color.WHITE)
        b.tvFechaVencimiento.text = expiryDate
        if (expiryDate != "Selecciona la fecha") b.tvFechaVencimiento.setTextColor(Color.WHITE)
        
        if (productId != null) {
            b.tvTitleRegistrar.text = "Editar producto"
            b.ivRegistrarIcon.setImageResource(android.R.drawable.ic_menu_edit)
            b.btnGuardarProducto.text = "Actualizar producto"
            initialImageBase64?.let { b.ivProductoPreview.setImageBitmap(base64ToBitmap(it)) }
        }

        // Búsqueda en catálogo al escribir nombre
        b.etNombreProducto.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {
                val nom = s?.toString()?.trim() ?: ""
                if (nom.length > 2 && productId == null) {
                    currentStoreId?.let { sid ->
                        db.collection("tiendas").document(sid).collection("catalogo").document(nom).get().addOnSuccessListener { doc ->
                            if (doc.exists()) {
                                b.tvCategoria.text = doc.getString("categoria") ?: "Otros"
                                b.tvCategoria.setTextColor(Color.WHITE)
                                b.etMarca.setText(doc.getString("marca") ?: "")
                                b.etPresentacion.setText(doc.getString("presentacion") ?: "")
                                doc.getString("imagen")?.let { img ->
                                    initialImageBase64 = img
                                    b.ivProductoPreview.setImageBitmap(base64ToBitmap(img))
                                }
                                Toast.makeText(ctx, "Producto encontrado en catálogo", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }
            }
            override fun beforeTextChanged(s: CharSequence?, st: Int, c: Int, a: Int) {}
            override fun onTextChanged(s: CharSequence?, st: Int, be: Int, c: Int) {}
        })

        b.btnTestNotification.setOnClickListener {
            NotificationHelper.sendTestNotification(ctx)
            Toast.makeText(ctx, "Enviando notificación de prueba...", Toast.LENGTH_SHORT).show()
        }

        b.btnBack.setOnClickListener { navController.popBackStack() }
        b.btnCancelar.setOnClickListener { navController.popBackStack() }
        b.layoutFotoPicker.setOnClickListener { view ->
            val p = PopupMenu(ctx, view)
            p.menu.add("Cámara"); p.menu.add("Galería")
            p.setOnMenuItemClickListener { if (it.title == "Cámara") camera.launch(null) else gallery.launch("image/*"); true }
            p.show()
        }
        b.btnCategoriaSelector.setOnClickListener { view ->
            val p = PopupMenu(ctx, view)
            listOf("Frutas y Verduras", "Carnes y Mariscos", "Refrigerados", "Congelados", "Panadería", "Abarrotes", "Bebidas", "Snacks y Dulces", "Limpieza del Hogar", "Higiene Personal", "Salud y Farmacia", "Bebés", "Mascotas", "Ferretería", "Hogar", "Electrónica", "Papelería y Oficina", "Ropa y Accesorios", "Licores y Cervezas").forEach { p.menu.add(it) }
            p.setOnMenuItemClickListener { b.tvCategoria.text = it.title; b.tvCategoria.setTextColor(Color.WHITE); true }
            p.show()
        }
        b.btnFechaVencimiento.setOnClickListener {
            val c = Calendar.getInstance()
            DatePickerDialog(ctx, { _, y, m, d -> b.tvFechaVencimiento.text = "$d/${m+1}/$y"; b.tvFechaVencimiento.setTextColor(Color.WHITE) }, c.get(Calendar.YEAR), c.get(Calendar.MONTH), c.get(Calendar.DAY_OF_MONTH)).show()
        }
        b.btnGuardarProducto.setOnClickListener {
            val nom = b.etNombreProducto.text.toString().trim()
            val cat = b.tvCategoria.text.toString()
            val can = b.etCantidad.text.toString().trim()
            val fec = b.tvFechaVencimiento.text.toString()
            if (nom.isNotEmpty() && cat != "Selecciona una categoría" && fec != "Selecciona la fecha" && can.isNotEmpty()) {
                var imgBase64 = initialImageBase64
                try {
                    selectedBitmap?.let { imgBase64 = bitmapToBase64(it) }
                    selectedUri?.let { uri -> val stream = context.contentResolver.openInputStream(uri); val bmp = BitmapFactory.decodeStream(stream); bmp?.let { imgBase64 = bitmapToBase64(it) } }
                } catch (_: Exception) {}
                
                val p = mutableMapOf<String, Any?>(
                    "nombre" to nom, "categoria" to cat, "cantidad" to can, "fechaVencimiento" to fec, 
                    "marca" to b.etMarca.text.toString(), "presentacion" to b.etPresentacion.text.toString(), 
                    "usuarioId" to FirebaseAuth.getInstance().currentUser?.uid, "imagen" to imgBase64
                )

                val storeId = currentStoreId ?: return@setOnClickListener
                val productsRef = db.collection("tiendas").document(storeId).collection("productos")
                val catalogRef = db.collection("tiendas").document(storeId).collection("catalogo")

                if (productId == null) {
                    p["fechaRegistro"] = Timestamp.now()
                    productsRef.add(p).addOnSuccessListener { 
                        catalogRef.document(nom).set(hashMapOf("nombre" to nom, "categoria" to cat, "marca" to b.etMarca.text.toString(), "presentacion" to b.etPresentacion.text.toString(), "imagen" to imgBase64))
                        NotificationHelper.scheduleProductNotifications(context, nom, fec)
                        navController.navigate("productos") { popUpTo("home") } 
                    }
                } else {
                    productsRef.document(productId).update(p.toMap()).addOnSuccessListener {
                        NotificationHelper.scheduleProductNotifications(context, nom, fec)
                        Toast.makeText(ctx, "Actualizado", Toast.LENGTH_SHORT).show()
                        navController.navigate("productos") { popUpTo("home") } 
                    }
                }
            } else { Toast.makeText(ctx, "Faltan datos obligatorios (*)", Toast.LENGTH_SHORT).show() }
        }
        b.root
    }, update = { root ->
        val b = RegistrarproductoActivityBinding.bind(root)
        if (selectedBitmap != null) b.ivProductoPreview.setImageBitmap(selectedBitmap)
        else if (selectedUri != null) b.ivProductoPreview.setImageURI(selectedUri)

        // Render Catalog History
        b.llCatalogHistory.removeAllViews()
        catalogList.forEach { item ->
            val itemBinding = ItemCatalogoBinding.inflate(inflater, b.llCatalogHistory, false)
            val name = item["nombre"] as? String ?: "N/A"
            val cat = item["categoria"] as? String ?: "Otros"
            val marc = item["marca"] as? String ?: "N/A"
            val pres = item["presentacion"] as? String ?: "N/A"
            val img = item["imagen"] as? String

            itemBinding.tvCatalogName.text = name
            itemBinding.tvCatalogInfo.text = "$cat | $marc"
            if (!img.isNullOrEmpty()) {
                itemBinding.ivCatalogImage.setImageBitmap(base64ToBitmap(img))
            } else {
                itemBinding.ivCatalogImage.setImageResource(android.R.drawable.ic_menu_gallery)
            }

            itemBinding.root.setOnClickListener {
                productName = name
                category = cat
                brand = marc
                presentation = pres
                initialImageBase64 = img
                selectedBitmap = null
                selectedUri = null
                
                b.etNombreProducto.setText(name)
                b.tvCategoria.text = cat
                b.tvCategoria.setTextColor(Color.WHITE)
                b.etMarca.setText(marc)
                b.etPresentacion.setText(pres)
                if (!img.isNullOrEmpty()) b.ivProductoPreview.setImageBitmap(base64ToBitmap(img))
                else b.ivProductoPreview.setImageResource(android.R.drawable.ic_menu_camera)
                
                Toast.makeText(context, "Información cargada de: $name", Toast.LENGTH_SHORT).show()
            }
            b.llCatalogHistory.addView(itemBinding.root)
        }
    })
}

private fun loadProductData(db: FirebaseFirestore, storeId: String?, productId: String?, onComplete: (Map<String, Any?>?) -> Unit) {
    if (productId != null && storeId != null) {
        db.collection("tiendas").document(storeId).collection("productos").document(productId).get().addOnSuccessListener { onComplete(it.data) }
    } else { onComplete(null) }
}
