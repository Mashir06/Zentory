package com.example.zentoryapp.uipr

import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.ActivitySelectionStoreBinding
import com.example.zentoryapp.databinding.DialogAddMinisuperBinding
import com.example.zentoryapp.databinding.DialogJoinStoreBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.*

@Composable
fun SelectionStoreScreen(navController: NavController) {
    val context = LocalContext.current
    val db = FirebaseFirestore.getInstance()
    val auth = FirebaseAuth.getInstance()
    val user = auth.currentUser
    
    var userName by remember { mutableStateOf("") }

    LaunchedEffect(user?.uid) {
        user?.uid?.let { uid ->
            db.collection("usuarios").document(uid).get().addOnSuccessListener { doc ->
                userName = doc.getString("nombre") ?: user.displayName ?: "Usuario"
            }
        }
    }

    fun showAddMinisuperDialog() {
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
                    "adminUid" to nombre,
                    "adminNombre" to userName,
                    "codigoInvitacion" to invitationCode,
                    "fechaCreacion" to com.google.firebase.Timestamp.now()
                )

                db.collection("tiendas").document(nombre).set(nuevaTienda).addOnSuccessListener {
                    val docId = nombre
                    // Agregamos al creador al equipo automáticamente
                    val adminStaffData = hashMapOf(
                        "uid" to user?.uid,
                        "nombre" to userName,
                        "correo" to user?.email,
                        "rol" to "Administrador",
                        "fechaUnion" to com.google.firebase.Timestamp.now()
                    )
                    db.collection("tiendas").document(docId).collection("personal").document(userName).set(adminStaffData)

                    // Actualizar el ID de la tienda en el documento del usuario
                    user?.uid?.let { uid -> 
                        db.collection("usuarios").document(uid).update("tiendaId", docId)
                            .addOnSuccessListener {
                                Toast.makeText(context, "Tienda '$nombre' creada", Toast.LENGTH_LONG).show()
                                dialog.dismiss()
                                navController.navigate("home") { popUpTo("selection_store") { inclusive = true } }
                            }
                    }
                }.addOnFailureListener {
                    Toast.makeText(context, "Error al crear tienda", Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(context, "El nombre es obligatorio", Toast.LENGTH_SHORT).show()
            }
        }
        dialog.show()
    }

    fun showJoinStoreDialog() {
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
                        val staffData = hashMapOf(
                            "uid" to user?.uid,
                            "nombre" to userName,
                            "correo" to user?.email,
                            "rol" to "Trabajador",
                            "fechaUnion" to com.google.firebase.Timestamp.now()
                        )
                        db.collection("tiendas").document(tiendaId).collection("personal").document(userName).set(staffData)
                            .addOnSuccessListener {
                                // Actualizar el ID de la tienda en el documento del usuario
                                user?.uid?.let { uid -> 
                                    db.collection("usuarios").document(uid).update("tiendaId", tiendaId)
                                        .addOnSuccessListener {
                                            Toast.makeText(context, "Te has unido a ${tiendaDoc.getString("nombre")}", Toast.LENGTH_SHORT).show()
                                            dialog.dismiss()
                                            navController.navigate("home") { popUpTo("selection_store") { inclusive = true } }
                                        }
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

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val binding = ActivitySelectionStoreBinding.inflate(LayoutInflater.from(ctx))
            
            binding.cvCreateStore.setOnClickListener { showAddMinisuperDialog() }
            binding.cvJoinStore.setOnClickListener { showJoinStoreDialog() }
            binding.btnSignOut.setOnClickListener {
                auth.signOut()
                navController.navigate("login") { popUpTo(0) }
            }
            
            binding.root
        }
    )
}
