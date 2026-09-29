package com.example.zentoryapp.uipr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Locale

fun openWordManual(context: Context) {
    val fileName = "manual.docx"
    val cacheFile = File(context.cacheDir, fileName)
    
    try {
        context.assets.open(fileName).use { input ->
            FileOutputStream(cacheFile).use { output ->
                input.copyTo(output)
            }
        }
        
        val uri = FileProvider.getUriForFile(
            context,
            "com.example.zentoryapp.fileprovider",
            cacheFile
        )
        
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        
        context.startActivity(Intent.createChooser(intent, "Abrir manual con..."))
    } catch (e: Exception) {
        e.printStackTrace()
        android.widget.Toast.makeText(context, "No se pudo encontrar el archivo del manual en los recursos de la app.", android.widget.Toast.LENGTH_LONG).show()
    }
}

val sdf = SimpleDateFormat("d/M/yyyy", Locale.getDefault())

fun bitmapToBase64(bitmap: Bitmap): String {
    val resized = Bitmap.createScaledBitmap(bitmap, 400, (400 * (bitmap.height.toFloat() / bitmap.width)).toInt(), true)
    val outputStream = ByteArrayOutputStream()
    resized.compress(Bitmap.CompressFormat.JPEG, 70, outputStream)
    return Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)
}

fun base64ToBitmap(base64Str: String): Bitmap? {
    return try {
        val bytes = Base64.decode(base64Str, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    } catch (e: Exception) { null }
}

data class ProductItem(
    val id: String,
    val nombre: String,
    val categoria: String,
    val marca: String,
    val presentacion: String,
    val fechaVencimiento: String,
    val fechaRegistro: String,
    val cantidad: String,
    val statusText: String,
    val statusColor: String,
    val bitmap: Bitmap? = null
)
