package com.example.zentoryapp.uipr

import android.view.LayoutInflater
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.AjustesActivityBinding
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.auth.FirebaseAuth

@Composable 
fun SettingsScreen(navController: NavController) { 
    AndroidView(
        modifier = Modifier.fillMaxSize(), 
        factory = { context -> 
            val b = AjustesActivityBinding.inflate(LayoutInflater.from(context))
            val auth = FirebaseAuth.getInstance()
            
            // Configuración de Google Sign-In para el cierre de sesión
            val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestIdToken(context.getString(R.string.default_web_client_id))
                .requestEmail()
                .build()
            val googleSignInClient = GoogleSignIn.getClient(context, gso)

            val prefs = context.getSharedPreferences("zentory_prefs", android.content.Context.MODE_PRIVATE)

            // Cargar estado inicial de notificaciones
            b.switchNotifications.isChecked = prefs.getBoolean("notifications_enabled", true)

            // Guardar cambios en notificaciones
            b.switchNotifications.setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("notifications_enabled", isChecked).apply()
            }

            // Permitir que al tocar la fila también se active el switch
            b.optionNotifications.setOnClickListener {
                b.switchNotifications.isChecked = !b.switchNotifications.isChecked
            }

            b.btnBack.setOnClickListener { navController.popBackStack() }
            b.perfilbtn.setOnClickListener { navController.navigate("profile") }
            b.optionPrivacy.setOnClickListener { navController.navigate("privacy_settings") }
            b.optionHelp.setOnClickListener { navController.navigate("help") }
            
            b.btnLogout.setOnClickListener { 
                // Cerrar sesión en Firebase
                auth.signOut()
                
                // Cerrar sesión en Google para limpiar la cuenta predeterminada
                googleSignInClient.signOut().addOnCompleteListener {
                    navController.navigate("login") { 
                        popUpTo(0) { inclusive = true } 
                    }
                }
            }
            b.root 
        }
    ) 
}
