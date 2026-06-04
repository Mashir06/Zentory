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
import android.widget.PopupMenu
import android.view.View
import com.example.zentoryapp.databinding.HomeActivityBinding
import com.example.zentoryapp.databinding.CalendarioActivityBinding
import com.example.zentoryapp.databinding.QrActivityBinding
import com.example.zentoryapp.databinding.ProductosActivityBinding
import com.example.zentoryapp.databinding.MainActivityBinding
import com.example.zentoryapp.databinding.RegistroActivityBinding
import com.example.zentoryapp.databinding.PerfilActivityBinding

// Función auxiliar para el menú superior
fun showTopMenu(context: android.content.Context, view: View, navController: androidx.navigation.NavController) {
    val popup = PopupMenu(context, view)
    popup.menu.add("Mi Perfil")
    popup.menu.add("Ajustes")
    popup.menu.add("Cerrar Sesión")
    
    popup.setOnMenuItemClickListener { menuItem ->
        when (menuItem.title) {
            "Mi Perfil" -> { navController.navigate("profile"); true }
            "Ajustes" -> { navController.navigate("settings"); true }
            "Cerrar Sesión" -> {
                navController.navigate("login") {
                    popUpTo("home") { inclusive = true }
                }
                true
            }
            else -> false
        }
    }
    popup.show()
}

// Pantalla de Login (main_activity.xml)
@Composable
fun LoginScreen(onLoginSuccess: () -> Unit, onNavigateToRegister: () -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = MainActivityBinding.inflate(LayoutInflater.from(context))
            binding.btnIniciarSesion.setOnClickListener {
                onLoginSuccess()
            }
            binding.btnGoogle.setOnClickListener {
                onLoginSuccess()
            }
            binding.tvRegistrateAqui.setOnClickListener {
                onNavigateToRegister()
            }
            binding.root
        }
    )
}

// Pantalla de Registro (registro_activity.xml)
@Composable
fun RegistroScreen(onRegisterSuccess: () -> Unit, onNavigateToLogin: () -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = RegistroActivityBinding.inflate(LayoutInflater.from(context))
            binding.btnRegistrarse.setOnClickListener {
                onRegisterSuccess()
            }
            binding.tvVolverLogin.setOnClickListener {
                onNavigateToLogin()
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
            binding.bottomNavigationView.selectedItemId = R.id.nav_home
            
            binding.btnTopProfile.setOnClickListener { view ->
                showTopMenu(context, view, navController)
            }
            
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> true
                    R.id.nav_productos -> { navController.navigate("productos"); true }
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_perfil -> { navController.navigate("profile"); true }
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
            binding.bottomNavigationView.selectedItemId = R.id.nav_calendario
            
            binding.btnTopProfile.setOnClickListener { view ->
                showTopMenu(context, view, navController)
            }
            
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_productos -> { navController.navigate("productos"); true }
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_calendario -> true
                    R.id.nav_perfil -> { navController.navigate("profile"); true }
                    else -> false
                }
            }
            binding.root
        }
    )
}

// Pantalla de QR (qr_activity.xml)
@Composable
fun QRScreen(navController: androidx.navigation.NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = QrActivityBinding.inflate(LayoutInflater.from(context))
            binding.bottomNavigationView.selectedItemId = R.id.nav_escanear
            
            binding.btnTopProfile.setOnClickListener { view ->
                showTopMenu(context, view, navController)
            }
            
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_productos -> { navController.navigate("productos"); true }
                    R.id.nav_escanear -> true
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_perfil -> { navController.navigate("profile"); true }
                    else -> false
                }
            }
            binding.root
        }
    )
}

// Pantalla de Productos (productos_activity.xml)
@Composable
fun ProductosScreen(navController: androidx.navigation.NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = ProductosActivityBinding.inflate(LayoutInflater.from(context))
            binding.bottomNavigationView.selectedItemId = R.id.nav_productos
            
            binding.btnTopProfile.setOnClickListener { view ->
                showTopMenu(context, view, navController)
            }
            
            binding.btnCategoria.setOnClickListener { view ->
                val popup = PopupMenu(context, view)
                popup.menu.add("Lácteos")
                popup.menu.add("Bebidas")
                popup.menu.add("Otros")
                popup.setOnMenuItemClickListener { menuItem ->
                    binding.btnCategoria.text = menuItem.title
                    true
                }
                popup.show()
            }
            binding.btnMarca.setOnClickListener { view ->
                val popup = PopupMenu(context, view)
                popup.menu.add("FEDURO")
                popup.menu.add("TOLEDANO")
                popup.menu.add("Nestlé")
                popup.setOnMenuItemClickListener { menuItem ->
                    binding.btnMarca.text = menuItem.title
                    true
                }
                popup.show()
            }
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_productos -> true
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_perfil -> { navController.navigate("profile"); true }
                    else -> false
                }
            }
            binding.root
        }
    )
}

// Pantalla de Perfil (perfil_activity.xml)
@Composable
fun ProfileScreen(navController: androidx.navigation.NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = PerfilActivityBinding.inflate(LayoutInflater.from(context))
            binding.bottomNavigationView.selectedItemId = R.id.nav_perfil
            
            // --- Lógica de Roles (Simulación) ---
            // Cambia esta variable a "worker" para ver la vista de trabajador
            val userRole = "admin" 
            
            if (userRole == "worker") {
                // Vista para Trabajador
                binding.tvPerfilNombre.text = "Carlos Ruiz"
                binding.tvPerfilRol.text = "Trabajador de Inventario"
                
                // Ocultamos las secciones que solo el Admin debe ver
                binding.layoutMinisupers.visibility = View.GONE
                binding.layoutPersonal.visibility = View.GONE
            } else {
                // Vista para Administrador (por defecto en el XML)
                binding.tvPerfilNombre.text = "Juan Pérez"
                binding.tvPerfilRol.text = "Administrador Principal"
                
                binding.layoutMinisupers.visibility = View.VISIBLE
                binding.layoutPersonal.visibility = View.VISIBLE
            }
            // ------------------------------------

            binding.btnTopProfile.setOnClickListener { view ->
                showTopMenu(context, view, navController)
            }

            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_productos -> { navController.navigate("productos"); true }
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_perfil -> true
                    else -> false
                }
            }
            binding.btnLogout.setOnClickListener {
                navController.navigate("login") {
                    popUpTo("home") { inclusive = true }
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
