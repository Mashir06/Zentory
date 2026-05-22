package com.example.zentoryapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.zentoryapp.ui.theme.ZentoryAPPTheme
import com.example.zentoryapp.LoginScreen
import com.example.zentoryapp.HomeScreen
import com.example.zentoryapp.CalendarioScreen
import com.example.zentoryapp.SettingsScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ZentoryAPPTheme {
                MainScreen()
            }
        }
    }
}

@Composable
fun MainScreen() {
    // Controlador de navegación
    val navController = rememberNavController()

    Scaffold { innerPadding ->
        // Configurar la navegación entre pantallas
        NavHost(
            navController = navController,
            startDestination = "login",
            modifier = Modifier.padding(innerPadding)
        ) {
            composable("login") {
                LoginScreen(onLoginSuccess = {
                    navController.navigate("home") {
                        popUpTo("login") { inclusive = true }
                    }
                })
            }
            composable("home") {
                HomeScreen(navController)
            }
            composable("calendar") {
                CalendarioScreen(navController)
            }
            composable("scan") {
                QRScreen(navController)
            }
            composable("productos") {
                ProductosScreen(navController)
            }
            composable("settings") {
                SettingsScreen()
            }
        }
    }
}
