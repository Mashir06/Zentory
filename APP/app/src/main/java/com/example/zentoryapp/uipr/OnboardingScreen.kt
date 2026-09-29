package com.example.zentoryapp.uipr

import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.example.zentoryapp.databinding.DialogAddMinisuperBinding
import com.example.zentoryapp.databinding.DialogJoinStoreBinding
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.*

@Composable
fun OnboardingScreen(navController: NavController) {
    val context = LocalContext.current
    val db = FirebaseFirestore.getInstance()
    val auth = FirebaseAuth.getInstance()
    val user = auth.currentUser

    val backgroundGradient = Brush.verticalGradient(
        colors = listOf(Color(0xFF0F172A), Color(0xFF1E293B))
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundGradient)
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "¡Bienvenido a Zentory!",
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Para comenzar, necesitas estar vinculado a un Minisuper.",
            color = Color(0xFF94A3B8),
            fontSize = 16.sp,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Opción 1: Crear
        Button(
            onClick = { showAddMinisuperDialog(context, db, user) { navController.navigate("home") { popUpTo("onboarding") { inclusive = true } } } },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Crear mi propio Minisuper", fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(text = "o", color = Color(0xFF94A3B8))

        Spacer(modifier = Modifier.height(16.dp))

        // Opción 2: Unirse
        OutlinedButton(
            onClick = { showJoinStoreDialog(context, db, user) { navController.navigate("home") { popUpTo("onboarding") { inclusive = true } } } },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF10B981)),
            shape = RoundedCornerShape(12.dp),
            border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFF10B981))
        ) {
            Text("Unirse con código de invitación", fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        TextButton(onClick = { 
            auth.signOut()
            navController.navigate("login") { popUpTo(0) }
        }) {
            Text("Cerrar Sesión", color = Color(0xFFEF4444))
        }
    }
}

private fun showAddMinisuperDialog(context: android.content.Context, db: FirebaseFirestore, user: com.google.firebase.auth.FirebaseUser?, onSuccess: () -> Unit) {
    val dialogBinding = DialogAddMinisuperBinding.inflate(LayoutInflater.from(context))
    val dialog = AlertDialog.Builder(context, android.R.style.Theme_DeviceDefault_Dialog_NoActionBar)
        .setView(dialogBinding.root)
        .create()

    dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
    dialogBinding.btnGuardar.setOnClickListener {
        val nombre = dialogBinding.etNombreMinisuper.text.toString().trim()
        val ubicacion = dialogBinding.etUbicacionMinisuper.text.toString().trim()
        
        if (nombre.isNotEmpty()) {
            val invitationCode = UUID.randomUUID().toString().substring(0, 8).uppercase()
            val nuevaTienda = hashMapOf(
                "nombre" to nombre,
                "ubicacion" to ubicacion,
                "adminUid" to nombre, // El nombre del minisuper como adminUid
                "codigoInvitacion" to invitationCode,
                "fechaCreacion" to Timestamp.now()
            )

            // Usamos el nombre de la tienda como ID de documento
            db.collection("tiendas").document(nombre).set(nuevaTienda).addOnSuccessListener {
                // AGREGAR AL CREADOR COMO PERSONAL
                val adminStaffData = hashMapOf(
                    "uid" to user?.uid,
                    "nombre" to (user?.displayName ?: "Administrador"),
                    "correo" to user?.email,
                    "rol" to "Administrador",
                    "fechaUnion" to Timestamp.now()
                )
                db.collection("tiendas").document(nombre).collection("personal").document(user?.uid ?: "").set(adminStaffData)
                
                // Actualizar tienda activa en el perfil del usuario
                user?.uid?.let { uid -> db.collection("usuarios").document(uid).update("tiendaId", nombre) }

                Toast.makeText(context, "Tienda creada exitosamente", Toast.LENGTH_LONG).show()
                dialog.dismiss()
                onSuccess()
            }
        } else {
            Toast.makeText(context, "El nombre es obligatorio", Toast.LENGTH_SHORT).show()
        }
    }
    dialog.show()
}

private fun showJoinStoreDialog(context: android.content.Context, db: FirebaseFirestore, user: com.google.firebase.auth.FirebaseUser?, onSuccess: () -> Unit) {
    val dialogBinding = DialogJoinStoreBinding.inflate(LayoutInflater.from(context))
    val dialog = AlertDialog.Builder(context, android.R.style.Theme_DeviceDefault_Dialog_NoActionBar)
        .setView(dialogBinding.root)
        .create()

    dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
    dialogBinding.btnUnirse.setOnClickListener {
        val code = dialogBinding.etCodigoInvitacion.text.toString().trim().uppercase()
        if (code.isNotEmpty()) {
            db.collection("tiendas").whereEqualTo("codigoInvitacion", code).get().addOnSuccessListener { result ->
                if (!result.isEmpty) {
                    val tiendaDoc = result.documents[0]
                    val tiendaId = tiendaDoc.id
                    
                    // Obtener nombre del usuario actual
                    db.collection("usuarios").document(user?.uid ?: "").get().addOnSuccessListener { userDoc ->
                        val userName = userDoc.getString("nombre") ?: "Nuevo Trabajador"
                        
                        val staffData = hashMapOf(
                            "uid" to user?.uid,
                            "nombre" to userName,
                            "correo" to user?.email,
                            "rol" to "Trabajador",
                            "fechaUnion" to Timestamp.now()
                        )
                        
                        db.collection("tiendas").document(tiendaId).collection("personal").document(user?.uid ?: "").set(staffData)
                            .addOnSuccessListener {
                                Toast.makeText(context, "Te has unido a ${tiendaDoc.getString("nombre")}", Toast.LENGTH_SHORT).show()
                                dialog.dismiss()
                                onSuccess()
                            }
                    }
                } else {
                    Toast.makeText(context, "Código inválido", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    dialog.show()
}
