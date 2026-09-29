package com.example.zentoryapp.uipr

import android.content.Intent
import android.net.Uri
import android.view.LayoutInflater
import android.view.View
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.databinding.AyudaActivityBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

@Composable
fun AyudaScreen(navController: NavController) {
    val db = FirebaseFirestore.getInstance()
    val auth = FirebaseAuth.getInstance()
    val user = auth.currentUser

    var userName by remember { mutableStateOf("") }
    var storeName by remember { mutableStateOf("") }

    LaunchedEffect(user?.uid) {
        user?.uid?.let { uid ->
            db.collection("usuarios").document(uid).get().addOnSuccessListener { userDoc ->
                userName = userDoc.getString("nombre") ?: user.displayName ?: "Usuario"
                val tiendaId = userDoc.getString("tiendaId")
                if (tiendaId != null) {
                    db.collection("tiendas").document(tiendaId).get().addOnSuccessListener { tiendaDoc ->
                        storeName = tiendaDoc.getString("nombre") ?: "Sin tienda"
                    }
                }
            }
        }
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val b = AyudaActivityBinding.inflate(LayoutInflater.from(context))

            b.btnBack.setOnClickListener {
                navController.popBackStack()
            }

            b.optionFaq.setOnClickListener {
                navController.navigate("faq")
            }

            b.optionContact.setOnClickListener {
                if (b.layoutWhatsappOptions.visibility == View.VISIBLE) {
                    b.layoutWhatsappOptions.visibility = View.GONE
                    b.imgContactArrow.animate().rotation(0f).setDuration(200).start()
                } else {
                    b.layoutWhatsappOptions.visibility = View.VISIBLE
                    b.imgContactArrow.animate().rotation(90f).setDuration(200).start()
                }
            }

            b.optionTutorial.setOnClickListener {
                openWordManual(context)
            }

            b.root
        },
        update = { root ->
            val b = AyudaActivityBinding.bind(root)
            val context = root.context

            b.optionWhatsapp1.setOnClickListener {
                val message = "Hola, soy $userName de la tienda $storeName. Necesito soporte técnico."
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("https://wa.me/67968449?text=${Uri.encode(message)}")
                }
                context.startActivity(intent)
            }

            b.optionWhatsapp2.setOnClickListener {
                val message = "Hola, soy $userName de la tienda $storeName. Tengo una consulta general."
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("https://wa.me/61857395?text=${Uri.encode(message)}")
                }
                context.startActivity(intent)
            }
        }
    )
}
