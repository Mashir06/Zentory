package com.example.zentoryapp.uipr

import android.graphics.Paint
import android.text.method.HideReturnsTransformationMethod
import android.text.method.PasswordTransformationMethod
import android.view.LayoutInflater
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.MainActivityBinding
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore

@Composable
fun LoginScreen(onLoginSuccess: () -> Unit, onNavigateToRegister: () -> Unit) {
    val auth = FirebaseAuth.getInstance()
    val context = LocalContext.current

    val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
        .requestIdToken(context.getString(R.string.default_web_client_id))
        .requestEmail()
        .build()
        
    val googleSignInLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
        try {
            val account = task.getResult(ApiException::class.java)
            val credential = GoogleAuthProvider.getCredential(account.idToken, null)
            auth.signInWithCredential(credential)
                .addOnSuccessListener { result ->
                    val user = result.user
                    if (user != null) {
                        val db = FirebaseFirestore.getInstance()
                        db.collection("usuarios").document(user.uid).get().addOnSuccessListener { doc ->
                            if (!doc.exists()) {
                                val userData = hashMapOf(
                                    "nombre" to (user.displayName ?: "Usuario"),
                                    "correo" to (user.email ?: ""),
                                    "uid" to user.uid
                                )
                                db.collection("usuarios").document(user.uid).set(userData)
                            }
                            (context as? android.app.Activity)?.runOnUiThread {
                                onLoginSuccess()
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Toast.makeText(context, "Error de Firebase: ${e.message}", Toast.LENGTH_SHORT).show()
                }
        } catch (e: ApiException) {
            Toast.makeText(context, "Error de Google: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val binding = MainActivityBinding.inflate(LayoutInflater.from(ctx))
            
            binding.btnIniciarSesion.setOnClickListener {
                val correo = binding.etCorreo.text.toString().trim()
                val password = binding.etContrasena.text.toString().trim()

                if (correo.isNotEmpty() && password.isNotEmpty()) {
                    auth.signInWithEmailAndPassword(correo, password)
                        .addOnSuccessListener { result ->
                            val user = result.user
                            if (user != null) {
                                // Asegurar que el documento del usuario existe en Firestore con el UID correcto
                                val db = FirebaseFirestore.getInstance()
                                db.collection("usuarios").document(user.uid).get().addOnSuccessListener { doc ->
                                    if (!doc.exists()) {
                                        // Si no existe (migración o error previo), lo creamos
                                        val userData = hashMapOf("nombre" to (user.displayName ?: "Usuario"), "correo" to correo)
                                        db.collection("usuarios").document(user.uid).set(userData)
                                    }
                                    Toast.makeText(ctx, "¡Bienvenido!", Toast.LENGTH_SHORT).show()
                                    onLoginSuccess()
                                }
                            }
                        }
                        .addOnFailureListener { e ->
                            Toast.makeText(ctx, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                        }
                } else {
                    Toast.makeText(ctx, "Por favor llena todos los campos", Toast.LENGTH_SHORT).show()
                }
            }

            binding.btnGoogle.setOnClickListener {
                val googleSignInClient = GoogleSignIn.getClient(ctx, gso)
                googleSignInLauncher.launch(googleSignInClient.signInIntent)
            }

            binding.textView6.setOnClickListener {
                val correo = binding.etCorreo.text.toString().trim()
                if (correo.isNotEmpty()) {
                    auth.sendPasswordResetEmail(correo)
                        .addOnSuccessListener {
                            Toast.makeText(context, "Se ha enviado un correo para restablecer tu contraseña", Toast.LENGTH_LONG).show()
                        }
                        .addOnFailureListener { e ->
                            Toast.makeText(context, "Error al enviar correo: ${e.message}", Toast.LENGTH_SHORT).show()
                        }
                } else {
                    Toast.makeText(context, "Por favor, ingresa tu correo primero", Toast.LENGTH_SHORT).show()
                }
            }
            binding.tvRegistrateAqui.paintFlags = binding.tvRegistrateAqui.paintFlags or Paint.UNDERLINE_TEXT_FLAG
            binding.tvRegistrateAqui.setOnClickListener { onNavigateToRegister() }

            var isPasswordVisible = false
            binding.showpass.setOnClickListener {
                isPasswordVisible = !isPasswordVisible
                if (isPasswordVisible) {
                    binding.etContrasena.transformationMethod = HideReturnsTransformationMethod.getInstance()
                    binding.showpass.setImageResource(android.R.drawable.ic_menu_view) // You can change this to a "hidden" icon if you have one
                } else {
                    binding.etContrasena.transformationMethod = PasswordTransformationMethod.getInstance()
                    binding.showpass.setImageResource(android.R.drawable.ic_menu_view)
                }
                binding.etContrasena.setSelection(binding.etContrasena.text.length)
            }

            binding.root
        }
    )
}
