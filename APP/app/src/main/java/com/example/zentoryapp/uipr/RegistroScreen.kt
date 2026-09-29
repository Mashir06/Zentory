package com.example.zentoryapp.uipr

import android.graphics.Paint
import android.view.LayoutInflater
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.example.zentoryapp.databinding.RegistroActivityBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp

@Composable
fun RegistroScreen(onRegisterSuccess: () -> Unit, onNavigateToLogin: () -> Unit) {
    val auth = FirebaseAuth.getInstance()
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = RegistroActivityBinding.inflate(LayoutInflater.from(context))
            binding.btnRegistrarse.setOnClickListener {
                val nombre = binding.etNombre.text.toString().trim()
                val correo = binding.etEmail.text.toString().trim()
                val password = binding.etPassword.text.toString().trim()

                if (nombre.isNotEmpty() && correo.isNotEmpty() && password.isNotEmpty()) {
                    if (password.length < 6) {
                        Toast.makeText(context, "La contraseña debe tener al menos 6 caracteres", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }

                    // Intentamos crear el usuario
                    auth.createUserWithEmailAndPassword(correo, password)
                        .addOnSuccessListener { result ->
                            val user = result.user
                            if (user != null) {
                                val db = FirebaseFirestore.getInstance()
                                
                                // Información del usuario para Firestore
                                // NOTA: No guardamos la contraseña aquí por seguridad (Firebase Auth ya la gestiona de forma cifrada)
                                val usuario = hashMapOf(
                                    "nombre" to nombre,
                                    "correo" to correo,
                                    "uid" to user.uid,
                                    "fechaRegistro" to Timestamp.now()
                                )

                                db.collection("usuarios").document(user.uid).set(usuario)
                                    .addOnSuccessListener {
                                        Toast.makeText(context, "Registro exitoso", Toast.LENGTH_SHORT).show()
                                        onRegisterSuccess()
                                    }
                                    .addOnFailureListener { e ->
                                        Toast.makeText(context, "Error al guardar datos: ${e.message}", Toast.LENGTH_SHORT).show()
                                    }
                            }
                        }
                        .addOnFailureListener { e ->
                            // Verificamos si el error es porque el correo ya está registrado
                            when (e) {
                                is FirebaseAuthUserCollisionException -> {
                                    Toast.makeText(context, "Este correo ya está registrado. Intenta iniciar sesión.", Toast.LENGTH_LONG).show()
                                }
                                is FirebaseAuthInvalidCredentialsException -> {
                                    Toast.makeText(context, "El formato del correo electrónico no es válido.", Toast.LENGTH_SHORT).show()
                                }
                                else -> {
                                    Toast.makeText(context, "Error en el registro: ${e.message}", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
                } else {
                    Toast.makeText(context, "Por favor llena todos los campos", Toast.LENGTH_SHORT).show()
                }
            }
            binding.tvVolverLogin.paintFlags = binding.tvVolverLogin.paintFlags or Paint.UNDERLINE_TEXT_FLAG
            binding.tvVolverLogin.setOnClickListener { onNavigateToLogin() }
            binding.root
        }
    )
}
