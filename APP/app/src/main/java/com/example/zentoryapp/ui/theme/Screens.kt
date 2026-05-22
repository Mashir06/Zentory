package com.example.zentoryapp

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import android.view.LayoutInflater
import com.example.zentoryapp.databinding.HomeActivityBinding
import com.example.zentoryapp.databinding.CalendarioActivityBinding

// Pantalla de Login (main_activity.xml)
@Composable
fun LoginScreen(onLoginSuccess: () -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = com.example.zentoryapp.databinding.MainActivityBinding.inflate(LayoutInflater.from(context))
            binding.btnIniciarSesion.setOnClickListener {
                onLoginSuccess()
            }
            binding.root
        }
    )
}

// Pantalla de Inicio (home_activity.xml)
@Composable
fun HomeScreen(navController: androidx.navigation.NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = HomeActivityBinding.inflate(LayoutInflater.from(context))
            
            // Configurar navegación de la barra inferior en XML
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    com.example.zentoryapp.R.id.nav_home -> {
                        // Ya estamos aquí
                        true
                    }
                    com.example.zentoryapp.R.id.nav_calendario -> {
                        navController.navigate("calendar")
                        true
                    }
                    // Agrega otros casos según necesites
                    else -> false
                }
            }
            
            binding.root
        }
    )
}

// Pantalla de Calendario (calendario_activity.xml)
@Composable
fun CalendarioScreen(navController: androidx.navigation.NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = CalendarioActivityBinding.inflate(LayoutInflater.from(context))
            
            binding.bottomNavigation.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    com.example.zentoryapp.R.id.nav_home -> {
                        navController.navigate("home")
                        true
                    }
                    com.example.zentoryapp.R.id.nav_calendario -> {
                        // Ya estamos aquí
                        true
                    }
                    else -> false
                }
            }

            binding.root
        }
    )
}

// Pantalla de Ajustes
@Composable
fun SettingsScreen() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(text = "Pantalla de Ajustes", fontSize = 24.sp)
    }
}