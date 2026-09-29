package com.example.zentoryapp.uipr

import android.app.AlertDialog
import android.graphics.Typeface
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.PerfilActivityBinding
import com.example.zentoryapp.databinding.DialogAddMinisuperBinding
import com.example.zentoryapp.databinding.DialogJoinStoreBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.*

@Composable 
fun ProfileScreen(navController: NavController) {
    val context = LocalContext.current
    val db = FirebaseFirestore.getInstance()
    val auth = FirebaseAuth.getInstance()
    val user = auth.currentUser

    var userName by remember { mutableStateOf("Cargando...") }
    var userRole by remember { mutableStateOf("Usuario") }
    var activeTiendaId by remember { mutableStateOf<String?>(null) }
    var tiendasList by remember { mutableStateOf(listOf<Map<String, Any>>()) }
    var minisupersList by remember { mutableStateOf(listOf<Map<String, Any>>()) }
    var staffList by remember { mutableStateOf(listOf<Map<String, Any>>()) }

    fun loadTiendaDetails(tiendaId: String, tiendaNombre: String) {
        // Cargar personal
        db.collection("tiendas").document(tiendaId).collection("personal").get().addOnSuccessListener { staffRes ->
            staffList = staffRes.map { it.data + ("tiendaNombre" to tiendaNombre) }
            // Buscamos al usuario por su ID de documento O por su campo UID para mayor robustez
            val myMember = staffRes.documents.find { it.id == userName || it.getString("uid") == user?.uid }
            val role = myMember?.getString("rol") ?: "Trabajador"
            userRole = if (role == "Administrador") "Administrador Principal" else "Trabajador en $tiendaNombre"
        }

        // Cargar minisupers (sucursales)
        db.collection("tiendas").document(tiendaId).collection("minisupers").get().addOnSuccessListener { miniRes ->
            minisupersList = miniRes.map { it.data + ("id" to it.id) }
        }
    }


    fun handleOwnedStores(ownedStores: List<Map<String, Any>>, currentTiendaId: String?) {
        if (ownedStores.isNotEmpty()) {
            val finalId = if (ownedStores.any { it["id"] == currentTiendaId }) currentTiendaId!! else ownedStores.first()["id"] as String
            activeTiendaId = finalId
            val activeData = ownedStores.find { it["id"] == finalId }
            loadTiendaDetails(finalId, activeData?.get("nombre") as? String ?: "Tienda")
        } else if (currentTiendaId == null) {
            staffList = emptyList()
            userRole = "Usuario (Sin tiendas)"
        }
    }

    fun loadData() {
        val uid = user?.uid ?: return
        db.collection("usuarios").document(uid).get().addOnSuccessListener { userDoc ->
            if (!userDoc.exists()) return@addOnSuccessListener

            val fetchedName = userDoc.getString("nombre") ?: user.displayName ?: user.email ?: "Usuario"
            userName = fetchedName
            val currentTiendaId = userDoc.getString("tiendaId")
            val tiendasIds = userDoc.get("tiendasIds") as? List<String> ?: emptyList()
            
            // Combinamos las tiendas guardadas en la lista con la activa actual
            val idsToQuery = (tiendasIds + currentTiendaId).filterNotNull().distinct()

            if (idsToQuery.isNotEmpty()) {
                // Buscamos las tiendas por ID (máximo 10 por limitación de Firestore whereIn)
                db.collection("tiendas").whereIn(com.google.firebase.firestore.FieldPath.documentId(), idsToQuery.take(10)).get().addOnSuccessListener { res1 ->
                    // También buscamos tiendas por adminNombre para compatibilidad con datos antiguos
                    db.collection("tiendas").whereEqualTo("adminNombre", fetchedName).get().addOnSuccessListener { res2 ->
                        val allDocs = res1.documents + res2.documents
                        val allStores = allDocs.map { (it.data ?: emptyMap()) + ("id" to it.id) }.distinctBy { it["id"] }
                        tiendasList = allStores
                        
                        // Determinar cuál es la tienda activa
                        val finalActiveId = if (allStores.any { it["id"] == currentTiendaId }) currentTiendaId else allStores.firstOrNull()?.get("id") as? String
                        activeTiendaId = finalActiveId
                        
                        if (finalActiveId != null) {
                            val activeData = allStores.find { it["id"] == finalActiveId }
                            loadTiendaDetails(finalActiveId, activeData?.get("nombre") as? String ?: "Tienda")
                        } else {
                            userRole = "Usuario (Sin tiendas)"
                            staffList = emptyList()
                        }
                    }
                }
            } else {
                // Búsqueda legacy por nombre si no hay lista de IDs
                db.collection("tiendas").whereEqualTo("adminNombre", fetchedName).get().addOnSuccessListener { res ->
                    val owned = res.documents.map { (it.data ?: emptyMap()) + ("id" to it.id) }
                    tiendasList = owned
                    handleOwnedStores(owned, currentTiendaId)
                }
            }
        }
    }

    LaunchedEffect(user?.uid) { loadData() }

    fun showAddMinisuperDialog() {
        val dialogBinding = DialogAddMinisuperBinding.inflate(LayoutInflater.from(context))
        val dialog = AlertDialog.Builder(context).setView(dialogBinding.root).create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        dialogBinding.tvDialogTitle.text = "Nueva Tienda"
        dialogBinding.btnGuardar.text = "Crear"
        dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
        dialogBinding.btnGuardar.setOnClickListener {
            val nombre = dialogBinding.etNombreMinisuper.text.toString().trim()
            val ubicacion = dialogBinding.etUbicacionMinisuper.text.toString().trim()
            if (nombre.isNotEmpty()) {
                val code = UUID.randomUUID().toString().substring(0, 8).uppercase()
                val minisuper = hashMapOf(
                    "nombre" to nombre,
                    "ubicacion" to ubicacion,
                    "adminUid" to user?.uid,
                    "adminNombre" to userName,
                    "codigoInvitacion" to code,
                    "fechaCreacion" to com.google.firebase.Timestamp.now()
                )
                
                db.collection("tiendas").document(nombre).set(minisuper).addOnSuccessListener {
                    val staff = hashMapOf(
                        "uid" to (user?.uid ?: userName), 
                        "nombre" to userName, 
                        "correo" to user?.email, 
                        "rol" to "Administrador", 
                        "fechaUnion" to com.google.firebase.Timestamp.now()
                    )
                    // Usamos el NOMBRE como ID del documento en Firestore
                    db.collection("tiendas").document(nombre).collection("personal").document(userName).set(staff).addOnSuccessListener {
                        db.collection("usuarios").document(user?.uid ?: "").update(
                            "tiendaId", nombre,
                            "tiendasIds", com.google.firebase.firestore.FieldValue.arrayUnion(nombre)
                        ).addOnSuccessListener {
                            Toast.makeText(context, "Tienda '$nombre' creada", Toast.LENGTH_LONG).show()
                            dialog.dismiss()
                            loadData()
                        }
                    }
                }
            }
        }
        dialog.show()
        val width = (context.resources.displayMetrics.widthPixels * 0.9).toInt()
        dialog.window?.setLayout(width, android.view.ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    fun showEditStoreDialog(tiendaId: String, currentNombre: String, currentUbicacion: String, isSubMinisuper: Boolean = false) {
        val dialogBinding = DialogAddMinisuperBinding.inflate(LayoutInflater.from(context))
        val dialog = AlertDialog.Builder(context).setView(dialogBinding.root).create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        dialogBinding.tvDialogTitle.text = "Editar Tienda"
        dialogBinding.etNombreMinisuper.setText(currentNombre)
        dialogBinding.etUbicacionMinisuper.setText(currentUbicacion)
        dialogBinding.btnGuardar.text = "Actualizar"

        dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
        dialogBinding.btnGuardar.setOnClickListener {
            val nuevoNombre = dialogBinding.etNombreMinisuper.text.toString().trim()
            val nuevaUbicacion = dialogBinding.etUbicacionMinisuper.text.toString().trim()
            if (nuevoNombre.isNotEmpty()) {
                val ref = if (isSubMinisuper) {
                    db.collection("tiendas").document(activeTiendaId ?: "").collection("minisupers").document(tiendaId)
                } else {
                    db.collection("tiendas").document(tiendaId)
                }
                ref.update("nombre", nuevoNombre, "ubicacion", nuevaUbicacion).addOnSuccessListener {
                    Toast.makeText(context, "Tienda actualizada", Toast.LENGTH_SHORT).show()
                    dialog.dismiss()
                    loadData()
                }
            }
        }
        dialog.show()
        val width = (context.resources.displayMetrics.widthPixels * 0.9).toInt()
        dialog.window?.setLayout(width, android.view.ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    fun confirmDeleteStore(tiendaId: String, tiendaNombre: String, isSubMinisuper: Boolean = false) {
        AlertDialog.Builder(context)
            .setTitle("Eliminar Tienda")
            .setMessage("¿Estás seguro de que deseas eliminar '$tiendaNombre'? Se borrará toda la información, incluyendo personal, productos y sucursales.")
            .setPositiveButton("Eliminar") { _, _ ->
                val ref = if (isSubMinisuper) {
                    db.collection("tiendas").document(activeTiendaId ?: "").collection("minisupers").document(tiendaId)
                } else {
                    db.collection("tiendas").document(tiendaId)
                }

                if (isSubMinisuper) {
                    ref.delete().addOnSuccessListener {
                        Toast.makeText(context, "Sucursal eliminada", Toast.LENGTH_SHORT).show()
                        loadData()
                    }
                } else {
                    // Para tiendas principales, borramos subcolecciones manualmente
                    val subcollections = listOf("personal", "productos", "catalogo", "minisupers")
                    var processedCount = 0
                    
                    subcollections.forEach { coll ->
                        db.collection("tiendas").document(tiendaId).collection(coll).get().addOnSuccessListener { snapshot ->
                            val batch = db.batch()
                            
                            // Si es la colección de personal, limpiamos los datos en los perfiles de usuario
                            if (coll == "personal") {
                                snapshot.documents.forEach { doc ->
                                    val staffUid = doc.getString("uid")
                                    if (staffUid != null) {
                                        batch.update(db.collection("usuarios").document(staffUid), 
                                            "tiendaId", null,
                                            "tiendasIds", com.google.firebase.firestore.FieldValue.arrayRemove(tiendaId)
                                        )
                                    }
                                }
                            }

                            // Borramos todos los documentos de la subcolección
                            snapshot.documents.forEach { batch.delete(it.reference) }
                            
                            batch.commit().addOnCompleteListener {
                                processedCount++
                                if (processedCount == subcollections.size) {
                                    ref.delete().addOnSuccessListener {
                                        Toast.makeText(context, "Tienda y toda su información eliminada", Toast.LENGTH_SHORT).show()
                                        loadData()
                                    }
                                }
                            }
                        }.addOnFailureListener {
                            processedCount++
                            if (processedCount == subcollections.size) {
                                ref.delete().addOnSuccessListener { loadData() }
                            }
                        }
                    }
                }
            }
            .setNegativeButton("Cancelar", null)
            .show()
    }

    fun deleteStaffMember(staffName: String, tiendaId: String) {
        AlertDialog.Builder(context)
            .setTitle("Eliminar Personal")
            .setMessage("¿Estás seguro de que deseas eliminar a '$staffName' de esta tienda?")
            .setPositiveButton("Eliminar") { _, _ ->
                db.collection("tiendas").document(tiendaId).collection("personal").document(staffName).get().addOnSuccessListener { doc ->
                    // Intentamos obtener el UID real si existe para limpiar su tiendaId en el perfil de usuario
                    val actualUid = doc.getString("uid")
                    
                    db.collection("tiendas").document(tiendaId).collection("personal").document(staffName).delete().addOnSuccessListener {
                        if (actualUid != null && actualUid != staffName) {
                            val userRef = db.collection("usuarios").document(actualUid)
                            userRef.get().addOnSuccessListener { uDoc ->
                                val updateMap = mutableMapOf<String, Any>(
                                    "tiendasIds" to com.google.firebase.firestore.FieldValue.arrayRemove(tiendaId)
                                )
                                // Solo ponemos tiendaId en null si la tienda eliminada era la que tenía activa
                                if (uDoc.getString("tiendaId") == tiendaId) {
                                    updateMap["tiendaId"] = com.google.firebase.firestore.FieldValue.delete()
                                }
                                userRef.update(updateMap)
                            }
                        } else {
                            // Búsqueda legacy por nombre
                            db.collection("usuarios").whereEqualTo("nombre", staffName).get().addOnSuccessListener { uRes ->
                                if (!uRes.isEmpty) {
                                    uRes.documents[0].reference.update(
                                        "tiendaId", null,
                                        "tiendasIds", com.google.firebase.firestore.FieldValue.arrayRemove(tiendaId)
                                    )
                                }
                            }
                        }
                        Toast.makeText(context, "$staffName eliminado", Toast.LENGTH_SHORT).show()
                        loadData()
                    }
                }
            }
            .setNegativeButton("Cancelar", null)
            .show()
    }

    fun showJoinStoreDialog() {
        val dialogBinding = DialogJoinStoreBinding.inflate(LayoutInflater.from(context))
        val dialog = AlertDialog.Builder(context, android.R.style.Theme_DeviceDefault_Dialog_NoActionBar)
            .setView(dialogBinding.root).create()

        dialogBinding.btnCancelar.setOnClickListener { dialog.dismiss() }
        dialogBinding.btnUnirse.setOnClickListener {
            val code = dialogBinding.etCodigoInvitacion.text.toString().trim().uppercase()
            if (code.isNotEmpty()) {
                val uid = user?.uid ?: return@setOnClickListener
                // Nos aseguramos de tener el nombre más reciente antes de registrar al trabajador
                db.collection("usuarios").document(uid).get().addOnSuccessListener { uDoc ->
                    val myName = uDoc.getString("nombre") ?: userName
                    if (myName == "Cargando...") {
                        Toast.makeText(context, "Espera a que cargue tu perfil", Toast.LENGTH_SHORT).show()
                        return@addOnSuccessListener
                    }

                    db.collection("tiendas").whereEqualTo("codigoInvitacion", code).get().addOnSuccessListener { result ->
                        if (!result.isEmpty) {
                            val tId = result.documents[0].id
                            val staff = hashMapOf(
                                "uid" to uid, 
                                "nombre" to myName, 
                                "correo" to user?.email, 
                                "rol" to "Trabajador", 
                                "fechaUnion" to com.google.firebase.Timestamp.now()
                            )
                            db.collection("tiendas").document(tId).collection("personal").document(myName).set(staff).addOnSuccessListener {
                                db.collection("usuarios").document(uid).update(
                                    "tiendaId", tId,
                                    "tiendasIds", com.google.firebase.firestore.FieldValue.arrayUnion(tId)
                                ).addOnSuccessListener {
                                    Toast.makeText(context, "Te has unido a la tienda", Toast.LENGTH_SHORT).show()
                                    dialog.dismiss()
                                    loadData()
                                }
                            }
                        } else {
                            Toast.makeText(context, "Código no válido", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
        }
        dialog.show()
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx -> PerfilActivityBinding.inflate(LayoutInflater.from(ctx)).root },
        update = { root ->
            val b = PerfilActivityBinding.bind(root)
            val ctx = root.context
            b.btnBack.setOnClickListener { navController.popBackStack() }
            b.btnAddMinisuper.setOnClickListener { showAddMinisuperDialog() }
            b.btnJoinStore.setOnClickListener { showJoinStoreDialog() }
            b.tvPerfilNombre.text = userName
            b.tvPerfilRol.text = userRole
            
            b.containerMinisupers.removeAllViews()
            
            // 1. Mostrar la tienda principal activa (donde el usuario está trabajando actualmente)
            tiendasList.find { it["id"] == activeTiendaId }?.let { tienda ->
                val card = androidx.cardview.widget.CardView(ctx).apply {
                    val lp = LinearLayout.LayoutParams(-1, -2).apply { setMargins(0, 16, 0, 16) }
                    layoutParams = lp
                    radius = 32f
                    cardElevation = 8f
                    setCardBackgroundColor(android.graphics.Color.parseColor("#065F46")) // Verde oscuro para la activa
                    
                    val mainLayout = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
                    addView(mainLayout)

                    mainLayout.addView(LinearLayout(ctx).apply {
                        orientation = LinearLayout.VERTICAL; setPadding(40, 40, 40, 40)
                        addView(android.widget.TextView(ctx).apply { text = "${tienda["nombre"]} (Actual)"; setTextColor(-1); setTypeface(null, android.graphics.Typeface.BOLD); textSize = 18f })
                        addView(android.widget.TextView(ctx).apply { text = tienda["ubicacion"] as? String; setTextColor(android.graphics.Color.parseColor("#D1FAE5")); textSize = 14f; setPadding(0, 8, 0, 0) })
                        
                        val code = tienda["codigoInvitacion"] as? String
                        if (!code.isNullOrEmpty()) {
                            addView(android.widget.TextView(ctx).apply { 
                                text = "Código: $code"
                                setTextColor(android.graphics.Color.parseColor("#D1FAE5"))
                                textSize = 13f
                                setPadding(0, 8, 0, 0)
                                setOnClickListener {
                                    val clipboard = ctx.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                    val clip = android.content.ClipData.newPlainText("Código de Tienda", code)
                                    clipboard.setPrimaryClip(clip)
                                    Toast.makeText(ctx, "Código copiado: $code", Toast.LENGTH_SHORT).show()
                                }
                            })
                        }
                    })

                    val actionsLayout = LinearLayout(ctx).apply {
                        orientation = LinearLayout.HORIZONTAL; gravity = android.view.Gravity.END
                        setPadding(0, 0, 20, 40); visibility = android.view.View.GONE
                        addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                            text = "Editar"; setTextColor(android.graphics.Color.parseColor("#D1FAE5"))
                            textSize = 12f; minHeight = 0; minWidth = 0; setPadding(20, 10, 20, 10)
                            setOnClickListener { showEditStoreDialog(tienda["id"] as String, tienda["nombre"] as String, tienda["ubicacion"] as? String ?: "") }
                        })
                        addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                            text = "Eliminar"; setTextColor(android.graphics.Color.parseColor("#FEF2F2"))
                            textSize = 12f; minHeight = 0; minWidth = 0; setPadding(20, 10, 20, 10)
                            setOnClickListener { confirmDeleteStore(tienda["id"] as String, tienda["nombre"] as String) }
                        })
                    }
                    mainLayout.addView(actionsLayout)

                    setOnClickListener {
                        actionsLayout.visibility = if (actionsLayout.visibility == android.view.View.GONE) android.view.View.VISIBLE else android.view.View.GONE
                    }
                }
                b.containerMinisupers.addView(card)
            }

            // 2. Mostrar los minisupers/sucursales vinculados a la tienda principal
            if (minisupersList.isNotEmpty()) {
                val header = android.widget.TextView(ctx).apply {
                    text = "Sucursales vinculadas"
                    setTextColor(android.graphics.Color.parseColor("#94A3B8"))
                    textSize = 13f
                    setPadding(16, 16, 16, 8)
                }
                b.containerMinisupers.addView(header)

                minisupersList.forEach { mini ->
                    val card = androidx.cardview.widget.CardView(ctx).apply {
                        val lp = LinearLayout.LayoutParams(-1, -2).apply { setMargins(0, 8, 0, 8) }
                        layoutParams = lp
                        radius = 32f
                        setCardBackgroundColor(android.graphics.Color.parseColor("#1E293B"))
                        
                        val mainLayout = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
                        addView(mainLayout)

                        mainLayout.addView(LinearLayout(ctx).apply {
                            orientation = LinearLayout.VERTICAL; setPadding(40, 40, 40, 40)
                            addView(android.widget.TextView(ctx).apply { text = mini["nombre"] as? String; setTextColor(-1); setTypeface(null, android.graphics.Typeface.BOLD); textSize = 16f })
                            addView(android.widget.TextView(ctx).apply { text = mini["ubicacion"] as? String; setTextColor(android.graphics.Color.parseColor("#94A3B8")); textSize = 13f; setPadding(0, 4, 0, 0) })
                            addView(android.widget.TextView(ctx).apply { 
                                val mCode = mini["codigoInvitacion"] as? String ?: ""
                                text = "Código: $mCode"
                                setTextColor(android.graphics.Color.parseColor("#10B981"))
                                textSize = 13f
                                setPadding(0, 8, 0, 0)
                                setOnClickListener {
                                    if (mCode.isNotEmpty()) {
                                        val clipboard = ctx.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                        val clip = android.content.ClipData.newPlainText("Código de Tienda", mCode)
                                        clipboard.setPrimaryClip(clip)
                                        Toast.makeText(ctx, "Código copiado: $mCode", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            })
                        })

                        val actionsLayout = LinearLayout(ctx).apply {
                            orientation = LinearLayout.HORIZONTAL; gravity = android.view.Gravity.END
                            setPadding(0, 0, 20, 40); visibility = android.view.View.GONE
                            addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                                text = "Editar"; setTextColor(android.graphics.Color.parseColor("#10B981"))
                                textSize = 12f; minHeight = 0; minWidth = 0; setPadding(20, 10, 20, 10)
                                setOnClickListener { showEditStoreDialog(mini["id"] as String, mini["nombre"] as String, mini["ubicacion"] as? String ?: "", true) }
                            })
                            addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                                text = "Eliminar"; setTextColor(android.graphics.Color.parseColor("#FF3B3B"))
                                textSize = 12f; minHeight = 0; minWidth = 0; setPadding(20, 10, 20, 10)
                                setOnClickListener { confirmDeleteStore(mini["id"] as String, mini["nombre"] as String, true) }
                            })
                        }
                        mainLayout.addView(actionsLayout)

                        setOnClickListener {
                            actionsLayout.visibility = if (actionsLayout.visibility == android.view.View.GONE) android.view.View.VISIBLE else android.view.View.GONE
                        }
                    }
                    b.containerMinisupers.addView(card)
                }
            }

            // 3. Mostrar otras tiendas donde el usuario es miembro (si existen)
            val otherTiendas = tiendasList.filter { it["id"] != activeTiendaId }
            if (otherTiendas.isNotEmpty()) {
                val header = android.widget.TextView(ctx).apply {
                    text = "Otras de mis tiendas"
                    setTextColor(android.graphics.Color.parseColor("#94A3B8"))
                    textSize = 13f
                    setPadding(16, 24, 16, 8)
                }
                b.containerMinisupers.addView(header)

                otherTiendas.forEach { tienda ->
                    val card = androidx.cardview.widget.CardView(ctx).apply {
                        val lp = LinearLayout.LayoutParams(-1, -2).apply { setMargins(0, 8, 0, 8) }
                        layoutParams = lp
                        radius = 32f
                        setCardBackgroundColor(android.graphics.Color.parseColor("#1E293B"))
                        
                        val mainLayout = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
                        addView(mainLayout)

                        mainLayout.addView(LinearLayout(ctx).apply {
                            orientation = LinearLayout.VERTICAL; setPadding(40, 40, 40, 40)
                            addView(android.widget.TextView(ctx).apply { text = tienda["nombre"] as? String; setTextColor(-1); setTypeface(null, android.graphics.Typeface.BOLD); textSize = 16f })
                            addView(android.widget.TextView(ctx).apply { text = "Tocar para ver opciones"; setTextColor(android.graphics.Color.parseColor("#10B981")); textSize = 11f })
                        })

                        val actionsLayout = LinearLayout(ctx).apply {
                            orientation = LinearLayout.HORIZONTAL; gravity = android.view.Gravity.END
                            setPadding(10, 0, 10, 40); visibility = android.view.View.GONE
                            
                            addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                                text = "Seleccionar"; setTextColor(android.graphics.Color.parseColor("#10B981"))
                                textSize = 11f; minHeight = 0; minWidth = 0; setPadding(15, 10, 15, 10)
                                setOnClickListener {
                                    val id = tienda["id"] as? String
                                    db.collection("usuarios").document(user?.uid ?: "").update("tiendaId", id).addOnSuccessListener {
                                        navController.navigate("home") { popUpTo(0) { inclusive = true } }
                                    }
                                }
                            })
                            addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                                text = "Editar"; setTextColor(android.graphics.Color.parseColor("#10B981"))
                                textSize = 11f; minHeight = 0; minWidth = 0; setPadding(15, 10, 15, 10)
                                setOnClickListener { showEditStoreDialog(tienda["id"] as String, tienda["nombre"] as String, tienda["ubicacion"] as? String ?: "") }
                            })
                            addView(android.widget.Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
                                text = "Eliminar"; setTextColor(android.graphics.Color.parseColor("#FF3B3B"))
                                textSize = 11f; minHeight = 0; minWidth = 0; setPadding(15, 10, 15, 10)
                                setOnClickListener { confirmDeleteStore(tienda["id"] as String, tienda["nombre"] as String) }
                            })
                        }
                        mainLayout.addView(actionsLayout)

                        setOnClickListener {
                            actionsLayout.visibility = if (actionsLayout.visibility == android.view.View.GONE) android.view.View.VISIBLE else android.view.View.GONE
                        }
                    }
                    b.containerMinisupers.addView(card)
                }
            }

            b.containerPersonal.removeAllViews()
            staffList.forEach { p ->
                val pName = p["nombre"] as? String ?: "Sin nombre"
                val pRol = p["rol"] as? String ?: "Trabajador"
                
                val card = androidx.cardview.widget.CardView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(-1, -2).apply { setMargins(0, 8, 0, 8) }
                    radius = 32f
                    setCardBackgroundColor(android.graphics.Color.parseColor("#1E293B"))
                    
                    val contentLayout = LinearLayout(ctx).apply {
                        orientation = LinearLayout.HORIZONTAL; setPadding(24, 24, 24, 24); gravity = 16
                    }
                    addView(contentLayout)

                    contentLayout.addView(android.widget.ImageView(ctx).apply { 
                        layoutParams = LinearLayout.LayoutParams(80, 80)
                        setImageResource(android.R.drawable.ic_menu_myplaces) 
                    })
                    
                    val textLayout = LinearLayout(ctx).apply {
                        orientation = LinearLayout.VERTICAL; setPadding(24, 0, 0, 0)
                        layoutParams = LinearLayout.LayoutParams(0, -2, 1f)
                        addView(android.widget.TextView(ctx).apply { text = pName; setTextColor(-1); setTypeface(null, Typeface.BOLD) })
                        addView(android.widget.TextView(ctx).apply { text = "$pRol - ${p["tiendaNombre"]}"; setTextColor(android.graphics.Color.parseColor("#94A3B8")); textSize = 11f })
                    }
                    contentLayout.addView(textLayout)

                    // Mostrar botón eliminar solo si el usuario actual es admin y no es su propio registro
                    if (userRole == "Administrador Principal" && pName != userName) {
                        contentLayout.addView(android.widget.ImageButton(ctx).apply {
                            layoutParams = LinearLayout.LayoutParams(70, 70)
                            setImageResource(android.R.drawable.ic_menu_delete)
                            setBackgroundColor(android.graphics.Color.TRANSPARENT)
                            setColorFilter(android.graphics.Color.parseColor("#EF4444"))
                            setPadding(10, 10, 10, 10)
                            setOnClickListener { deleteStaffMember(pName, activeTiendaId ?: "") }
                        })
                    }
                }
                b.containerPersonal.addView(card)
            }
        }
    )
}
