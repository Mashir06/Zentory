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
import com.example.zentoryapp.databinding.HomeActivityBinding
import com.example.zentoryapp.databinding.CalendarioActivityBinding
import com.example.zentoryapp.databinding.QrActivityBinding
import com.example.zentoryapp.databinding.ProductosActivityBinding
import com.example.zentoryapp.databinding.MainActivityBinding

// Pantalla de Login (main_activity.xml)
@Composable
fun LoginScreen(onLoginSuccess: () -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val binding = MainActivityBinding.inflate(LayoutInflater.from(context))
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
            
            binding.bottomNavigationView.selectedItemId = R.id.nav_home
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> true
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_productos -> { navController.navigate("productos"); true }
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
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_calendario -> true
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_productos -> { navController.navigate("productos"); true }
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
            binding.bottomNavigationView.setOnItemSelectedListener { item ->
                when (item.itemId) {
                    R.id.nav_home -> { navController.navigate("home"); true }
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_escanear -> true
                    R.id.nav_productos -> { navController.navigate("productos"); true }
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
            // Menú para Categoría
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

            // Menú para Marca
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
                    R.id.nav_calendario -> { navController.navigate("calendar"); true }
                    R.id.nav_escanear -> { navController.navigate("scan"); true }
                    R.id.nav_productos -> true
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
