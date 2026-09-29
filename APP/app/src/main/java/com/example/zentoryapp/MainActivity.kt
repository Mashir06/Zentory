package com.example.zentoryapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.zentoryapp.ui.theme.ZentoryAPPTheme
import com.example.zentoryapp.uipr.LoginScreen
import com.example.zentoryapp.uipr.RegistroScreen
import com.example.zentoryapp.uipr.HomeScreen
import com.example.zentoryapp.uipr.CalendarioScreen
import com.example.zentoryapp.uipr.QRScreen
import com.example.zentoryapp.uipr.ProductosScreen
import com.example.zentoryapp.uipr.ProfileScreen
import com.example.zentoryapp.uipr.SettingsScreen
import com.example.zentoryapp.uipr.PrivacySettingsScreen
import com.example.zentoryapp.uipr.AyudaScreen
import com.example.zentoryapp.uipr.FaqScreen
import com.example.zentoryapp.uipr.RegistrarProductoScreen
import com.example.zentoryapp.uipr.OnboardingScreen
import com.example.zentoryapp.uipr.StoreSelectionScreen
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

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
    val navController = rememberNavController()
    val auth = FirebaseAuth.getInstance()
    val db = FirebaseFirestore.getInstance()

    Scaffold { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = "check_session",
            modifier = Modifier.padding(innerPadding)
        ) {
            composable("check_session") {
                LaunchedEffect(Unit) {
                    val user = auth.currentUser
                    if (user != null) {
                        navController.navigate("check_store") { popUpTo(0) }
                    } else {
                        navController.navigate("login") { popUpTo(0) }
                    }
                }
            }
            composable("check_store") {
                LaunchedEffect(Unit) {
                    val user = auth.currentUser
                    if (user != null) {
                        db.collection("usuarios").document(user.uid).get()
                            .addOnSuccessListener { doc ->
                                if (doc.exists() && doc.getString("tiendaId") != null) {
                                    navController.navigate("home") { popUpTo(0) }
                                } else {
                                    navController.navigate("store_selection") { popUpTo(0) }
                                }
                            }
                            .addOnFailureListener {
                                navController.navigate("store_selection") { popUpTo(0) }
                            }
                    } else {
                        navController.navigate("login") { popUpTo(0) }
                    }
                }
            }
            composable("login") {
                LoginScreen(
                    onLoginSuccess = { navController.navigate("check_store") { popUpTo(0) } },
                    onNavigateToRegister = { navController.navigate("register") }
                )
            }
            composable("register") {
                RegistroScreen(
                    onRegisterSuccess = { navController.navigate("check_store") { popUpTo(0) } },
                    onNavigateToLogin = { navController.popBackStack() }
                )
            }
            composable("store_selection") {
                StoreSelectionScreen(navController)
            }
            composable("onboarding") {
                OnboardingScreen(navController)
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
            composable("profile") {
                ProfileScreen(navController)
            }
            composable("settings") {
                SettingsScreen(navController)
            }
            composable("help") {
                AyudaScreen(navController)
            }
            composable("faq") {
                FaqScreen(navController)
            }
            composable("privacy_settings") {
                PrivacySettingsScreen(navController)
            }
            composable(
                route = "add_product?productId={productId}&qrNombre={qrNombre}&qrCategoria={qrCategoria}&qrMarca={qrMarca}&qrPresentacion={qrPresentacion}",
                arguments = listOf(
                    navArgument("productId") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("qrNombre") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("qrCategoria") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("qrMarca") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("qrPresentacion") { type = NavType.StringType; nullable = true; defaultValue = null }
                )
            ) { backStackEntry ->
                val productId = backStackEntry.arguments?.getString("productId")
                val qrNombre = backStackEntry.arguments?.getString("qrNombre")
                val qrCategoria = backStackEntry.arguments?.getString("qrCategoria")
                val qrMarca = backStackEntry.arguments?.getString("qrMarca")
                val qrPresentacion = backStackEntry.arguments?.getString("qrPresentacion")
                RegistrarProductoScreen(navController, productId, qrNombre, qrCategoria, qrMarca, qrPresentacion)
            }
        }
    }
}
