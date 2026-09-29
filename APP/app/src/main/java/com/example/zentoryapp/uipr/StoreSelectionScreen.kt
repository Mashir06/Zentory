package com.example.zentoryapp.uipr

import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.databinding.ActivitySelectionStoreBinding
import com.example.zentoryapp.databinding.DialogAddMinisuperBinding
import com.example.zentoryapp.databinding.DialogJoinStoreBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.*

@Composable
fun StoreSelectionScreen(navController: NavController) {
    val auth = FirebaseAuth.getInstance()
    val db = FirebaseFirestore.getInstance()

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val binding = ActivitySelectionStoreBinding.inflate(LayoutInflater.from(ctx))

            binding.cvCreateStore.setOnClickListener {
                showCreateStoreDialog(ctx, db, auth, navController)
            }

            binding.cvJoinStore.setOnClickListener {
                showJoinStoreDialog(ctx, db, auth, navController)
            }

            binding.btnSignOut.setOnClickListener {
                auth.signOut()
                navController.navigate("login") {
                    popUpTo(0)
                }
            }

            binding.root
        }
    )
}

private fun showCreateStoreDialog(context: android.content.Context, db: FirebaseFirestore, auth: FirebaseAuth, navController: NavController) {
    val dialogBinding = DialogAddMinisuperBinding.inflate(LayoutInflater.from(context))
    val dialog = AlertDialog.Builder(context, android.R.style.Theme_DeviceDefault_Dialog_NoActionBar)
        .setView(dialogBinding.root)
        .create()

    dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
    dialogBinding.btnGuardar.setOnClickListener {
        val nombreTienda = dialogBinding.etNombreMinisuper.text.toString().trim()
        val ubicacion = dialogBinding.etUbicacionMinisuper.text.toString().trim()
        val user = auth.currentUser

        if (nombreTienda.isNotEmpty() && user != null) {
            // Obtenemos el nombre del administrador desde su perfil en Firestore
            db.collection("usuarios").document(user.uid).get().addOnSuccessListener { userDoc ->
                val userName = userDoc.getString("nombre") ?: user.displayName ?: "Administrador"
                val invitationCode = UUID.randomUUID().toString().substring(0, 8).uppercase()
                
                val nuevaTienda = hashMapOf(
                    "nombre" to nombreTienda,
                    "ubicacion" to ubicacion,
                    "adminUid" to userName, // Se guarda el nombre del administrador como ID
                    "adminNombre" to userName,
                    "codigoInvitacion" to invitationCode,
                    "fechaCreacion" to com.google.firebase.Timestamp.now()
                )

                db.collection("tiendas").document(nombreTienda).set(nuevaTienda).addOnSuccessListener {
                    val adminStaffData = hashMapOf(
                        "uid" to userName,
                        "nombre" to userName,
                        "correo" to user.email,
                        "rol" to "Administrador",
                        "fechaUnion" to com.google.firebase.Timestamp.now()
                    )
                    
                    // Usamos el NOMBRE como ID del documento en personal
                    db.collection("tiendas").document(nombreTienda).collection("personal").document(userName).set(adminStaffData)
                    db.collection("usuarios").document(user.uid).update("tiendaId", nombreTienda)

                    Toast.makeText(context, "Tienda '$nombreTienda' creada", Toast.LENGTH_LONG).show()
                    dialog.dismiss()
                    navController.navigate("home") { popUpTo(0) }
                }
            }
        } else {
            Toast.makeText(context, "El nombre de la tienda es obligatorio", Toast.LENGTH_SHORT).show()
        }
    }
    dialog.show()
}

private fun showJoinStoreDialog(context: android.content.Context, db: FirebaseFirestore, auth: FirebaseAuth, navController: NavController) {
    val dialogBinding = DialogJoinStoreBinding.inflate(LayoutInflater.from(context))
    val dialog = AlertDialog.Builder(context, android.R.style.Theme_DeviceDefault_Dialog_NoActionBar)
        .setView(dialogBinding.root)
        .create()

    dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
    dialogBinding.btnUnirse.setOnClickListener {
        val code = dialogBinding.etCodigoInvitacion.text.toString().trim().uppercase()
        val user = auth.currentUser

        if (code.isNotEmpty() && user != null) {
            db.collection("tiendas").whereEqualTo("codigoInvitacion", code).get().addOnSuccessListener { result ->
                if (!result.isEmpty) {
                    val tiendaDoc = result.documents[0]
                    val tiendaId = tiendaDoc.id
                    
                    // Obtenemos el nombre del usuario desde su perfil
                    db.collection("usuarios").document(user.uid).get().addOnSuccessListener { userDoc ->
                        val userName = userDoc.getString("nombre") ?: user.displayName ?: "Trabajador"
                        
                        val staffData = hashMapOf(
                            "uid" to userName,
                            "nombre" to userName,
                            "correo" to user.email,
                            "rol" to "Trabajador",
                            "fechaUnion" to com.google.firebase.Timestamp.now()
                        )

                        // Usamos el NOMBRE como ID del documento en personal
                        db.collection("tiendas").document(tiendaId).collection("personal").document(userName).set(staffData)
                            .addOnSuccessListener {
                                db.collection("usuarios").document(user.uid).update("tiendaId", tiendaId)
                                Toast.makeText(context, "Te has unido a ${tiendaDoc.getString("nombre")}", Toast.LENGTH_SHORT).show()
                                dialog.dismiss()
                                navController.navigate("home") { popUpTo(0) }
                            }
                    }
                } else {
                    Toast.makeText(context, "Código inválido", Toast.LENGTH_SHORT).show()
                }
            }
        } else {
            Toast.makeText(context, "El código es obligatorio", Toast.LENGTH_SHORT).show()
        }
    }
    dialog.show()
}
