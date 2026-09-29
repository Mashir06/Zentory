package com.example.zentoryapp.uipr

import android.view.LayoutInflater
import android.view.View
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.HomeActivityBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable 
fun HomeScreen(navController: NavController) { 
    val db = remember { FirebaseFirestore.getInstance() }
    val auth = remember { FirebaseAuth.getInstance() }
    var userName by remember { mutableStateOf("(Usuario)") }
    var currentStoreId by remember { mutableStateOf<String?>(null) }
    
    var goodCount by remember { mutableIntStateOf(0) }
    var expiringCount by remember { mutableIntStateOf(0) }
    var expiredCount by remember { mutableIntStateOf(0) }
    var tomorrowCount by remember { mutableIntStateOf(0) }
    
    var lacteosCount by remember { mutableIntStateOf(0) }
    var bebidasCount by remember { mutableIntStateOf(0) }
    var enlatadosCount by remember { mutableIntStateOf(0) }
    var panaderiaCount by remember { mutableIntStateOf(0) }
    var otrosCount by remember { mutableIntStateOf(0) }

    LaunchedEffect(auth.currentUser) {
        val uid = auth.currentUser?.uid ?: return@LaunchedEffect
        db.collection("usuarios").document(uid).get().addOnSuccessListener { doc ->
            userName = doc.getString("nombre") ?: auth.currentUser?.displayName ?: auth.currentUser?.email ?: "Usuario" 
            
            val userTiendaId = doc.getString("tiendaId")
            if (userTiendaId != null) {
                currentStoreId = userTiendaId
                fetchStats(db, userTiendaId) { g, e, x, t, cats -> 
                    goodCount = g; expiringCount = e; expiredCount = x; tomorrowCount = t
                    lacteosCount = cats["Lácteos"] ?: 0
                    bebidasCount = cats["Bebidas"] ?: 0
                    enlatadosCount = cats["Enlatados"] ?: 0
                    panaderiaCount = cats["Panadería"] ?: 0
                    otrosCount = cats["Otros"] ?: 0
                }
            } else {
                // Fallback: buscar por el campo adminUid (nombre de la tienda)
                db.collection("tiendas").whereEqualTo("adminUid", userName).get().addOnSuccessListener { adminRes ->
                    if (!adminRes.isEmpty) {
                        currentStoreId = adminRes.documents[0].id
                        currentStoreId?.let { 
                            db.collection("usuarios").document(uid).update("tiendaId", it)
                            fetchStats(db, it) { g, e, x, t, cats -> 
                                goodCount = g; expiringCount = e; expiredCount = x; tomorrowCount = t
                                lacteosCount = cats["Lácteos"] ?: 0
                                bebidasCount = cats["Bebidas"] ?: 0
                                enlatadosCount = cats["Enlatados"] ?: 0
                                panaderiaCount = cats["Panadería"] ?: 0
                                otrosCount = cats["Otros"] ?: 0
                            } 
                        }
                    } else {
                        db.collectionGroup("personal").whereEqualTo("uid", userName).get().addOnSuccessListener { workerRes ->
                            if (!workerRes.isEmpty) {
                                currentStoreId = workerRes.documents[0].reference.parent.parent?.id
                                currentStoreId?.let { 
                                    db.collection("usuarios").document(uid).update("tiendaId", it)
                                    fetchStats(db, it) { g, e, x, t, cats -> 
                                        goodCount = g; expiringCount = e; expiredCount = x; tomorrowCount = t
                                        lacteosCount = cats["Lácteos"] ?: 0
                                        bebidasCount = cats["Bebidas"] ?: 0
                                        enlatadosCount = cats["Enlatados"] ?: 0
                                        panaderiaCount = cats["Panadería"] ?: 0
                                        otrosCount = cats["Otros"] ?: 0
                                    } 
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AndroidView<View>(
        modifier = Modifier.fillMaxSize(), 
        factory = { context -> 
            HomeActivityBinding.inflate(LayoutInflater.from(context)).apply {
                bottomNavigationView.selectedItemId = R.id.nav_home
                btnTopProfile.setOnClickListener { navController.navigate("settings") }
                // tvVerTodasCategorias.setOnClickListener { navController.navigate("productos") }
                aletrahome.setOnClickListener {
                    // Acción al hacer clic en la alerta, por ejemplo ir a productos
                    navController.navigate("productos")
                }
                fabAddProduct.setOnClickListener { 
                    if (currentStoreId == null) {
                        Toast.makeText(context, "Debes unirte a una tienda antes de poder agregar un producto", Toast.LENGTH_SHORT).show()
                    } else {
                        navController.navigate("add_product") 
                    }
                }
                bottomNavigationView.setOnItemSelectedListener { item -> 
                    when (item.itemId) { 
                        R.id.nav_productos -> { navController.navigate("productos"); true }
                        R.id.nav_escanear -> { navController.navigate("scan"); true }
                        R.id.nav_calendario -> { navController.navigate("calendar"); true }
                        else -> true 
                    } 
                }
            }.root 
        },
        update = { root ->
            val b = HomeActivityBinding.bind(root)
            b.tvSaludo.text = "¡Hola, $userName! 👋"
            b.tvCountGood.text = goodCount.toString()
            b.tvCountExpiring.text = expiringCount.toString()
            b.tvCountExpired.text = expiredCount.toString()
            b.tvCountTotal.text = (goodCount + expiringCount + expiredCount).toString()
            
            b.aletrahome.visibility = if (tomorrowCount > 0) View.VISIBLE else View.GONE
            b.tvAlertTitle.text = "$tomorrowCount productos vencen mañana"

            b.tvCountLacteos.text = lacteosCount.toString()
            b.tvCountBebidas.text = bebidasCount.toString()
            b.tvCountEnlatados.text = enlatadosCount.toString()
            b.tvCountPanaderia.text = panaderiaCount.toString()
            b.tvCountOtros.text = otrosCount.toString()

            // Actualizar gráfico de dona
            val categoryData = mapOf(
                "Lácteos" to lacteosCount,
                "Bebidas" to bebidasCount,
                "Enlatados" to enlatadosCount,
                "Panadería" to panaderiaCount,
                "Otros" to otrosCount
            )
            val categoryColors = mapOf(
                "Lácteos" to android.graphics.Color.parseColor("#10B981"),
                "Bebidas" to android.graphics.Color.parseColor("#2563EB"),
                "Enlatados" to android.graphics.Color.parseColor("#7C3AED"),
                "Panadería" to android.graphics.Color.parseColor("#F97316"),
                "Otros" to android.graphics.Color.parseColor("#FBBF24")
            )
            b.inforueda.setData(categoryData, categoryColors)
        }
    ) 
}

private fun fetchStats(db: FirebaseFirestore, storeId: String, onComplete: (Int, Int, Int, Int, Map<String, Int>) -> Unit) {
    val sdf = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault())
    db.collection("tiendas").document(storeId).collection("productos").get().addOnSuccessListener { result ->
        val now = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
        var g = 0; var e = 0; var x = 0; var t = 0
        val cats = mutableMapOf("Lácteos" to 0, "Bebidas" to 0, "Enlatados" to 0, "Panadería" to 0, "Otros" to 0)
        
        result.forEach { doc ->
            // Conteo de estados
            try {
                val date = sdf.parse(doc.getString("fechaVencimiento") ?: "")
                val diff = if (date != null) (date.time - now) / (1000 * 60 * 60 * 24) else 99
                when {
                    diff <= 0 -> x++
                    diff <= 7 -> {
                        if (diff == 1L) t++
                        e++
                    }
                    else -> g++
                }
            } catch (_: Exception) { g++ }

            // Conteo de categorías
            val cat = doc.getString("categoria") ?: "Otros"
            when (cat) {
                "Refrigerados" -> cats["Lácteos"] = (cats["Lácteos"] ?: 0) + 1
                "Bebidas", "Licores y Cervezas" -> cats["Bebidas"] = (cats["Bebidas"] ?: 0) + 1
                "Abarrotes" -> cats["Enlatados"] = (cats["Enlatados"] ?: 0) + 1
                "Panadería" -> cats["Panadería"] = (cats["Panadería"] ?: 0) + 1
                else -> cats["Otros"] = (cats["Otros"] ?: 0) + 1
            }
        }
        onComplete(g, e, x, t, cats)
    }
}

