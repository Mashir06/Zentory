package com.example.zentoryapp.uipr

import android.view.LayoutInflater
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.databinding.PrivacyActivityBinding
import com.google.firebase.auth.FirebaseAuth

@Composable
fun PrivacySettingsScreen(navController: NavController) {
    val auth = FirebaseAuth.getInstance()
    
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val b = PrivacyActivityBinding.inflate(LayoutInflater.from(context))

            b.btnBack.setOnClickListener { navController.popBackStack() }

            b.optionChangePassword.setOnClickListener {
                val email = auth.currentUser?.email
                if (email != null) {
                    auth.sendPasswordResetEmail(email)
                        .addOnSuccessListener {
                            Toast.makeText(context, "Se ha enviado un correo para restablecer tu contraseña a $email", Toast.LENGTH_LONG).show()
                        }
                        .addOnFailureListener { e ->
                            Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                        }
                } else {
                    Toast.makeText(context, "No se pudo obtener el correo del usuario", Toast.LENGTH_SHORT).show()
                }
            }

            b.optionDeleteAccount.setOnClickListener {
                // Aquí podrías agregar un diálogo de confirmación antes de proceder
                Toast.makeText(context, "Opción no disponible en esta versión", Toast.LENGTH_SHORT).show()
            }

            b.root
        }
    )
}
