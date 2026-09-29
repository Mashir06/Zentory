package com.example.zentoryapp.uipr

import android.content.res.ColorStateList
import android.graphics.Color
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.widget.PopupMenu
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.ItemProductoBinding
import com.example.zentoryapp.databinding.ProductosActivityBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Calendar

@Composable
fun ProductosScreen(navController: NavController) {
    val db = remember { FirebaseFirestore.getInstance() }
    val auth = remember { FirebaseAuth.getInstance() }
    var allProducts by remember { mutableStateOf(listOf<ProductItem>()) }
    var filteredProducts by remember { mutableStateOf(listOf<ProductItem>()) }
    var selectedCategory by remember { mutableStateOf("Todas") }
    var selectedStatus by remember { mutableStateOf("Todos") }
    var searchQuery by remember { mutableStateOf("") }
    var expandedProductId by remember { mutableStateOf<String?>(null) }
    var currentStoreId by remember { mutableStateOf<String?>(null) }

    val refreshData = { storeId: String ->
        db.collection("tiendas").document(storeId).collection("productos").get().addOnSuccessListener { result ->
            val now = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
            allProducts = result.map { doc ->
                val fechaStr = doc.getString("fechaVencimiento") ?: ""
                val regTs = doc.getTimestamp("fechaRegistro")
                val regDateStr = if (regTs != null) sdf.format(regTs.toDate()) else "N/A"
                val imgBase64 = doc.getString("imagen")
                val bitmap = if (!imgBase64.isNullOrEmpty()) base64ToBitmap(imgBase64) else null
                
                val status = try {
                    val date = sdf.parse(fechaStr)
                    val diff = if (date != null) (date.time - now) / (1000 * 60 * 60 * 24) else 99
                    when {
                        diff <= 0 -> Pair("Vencido", "#EF4444")
                        diff <= 7 -> Pair("Por vencer", "#F59E0B")
                        else -> Pair("Buen estado", "#10B981")
                    }
                } catch (_: Exception) { Pair("Sin fecha", "#94A3B8") }
                ProductItem(id = doc.id, nombre = doc.getString("nombre") ?: "", categoria = doc.getString("categoria") ?: "Otros", marca = doc.getString("marca") ?: "N/A", presentacion = doc.getString("presentacion") ?: "N/A", fechaVencimiento = fechaStr, fechaRegistro = regDateStr, cantidad = doc.getString("cantidad") ?: "0", statusText = status.first, statusColor = status.second, bitmap = bitmap)
            }
            filteredProducts = allProducts
        }
    }

    LaunchedEffect(auth.currentUser) {
        val uid = auth.currentUser?.uid ?: return@LaunchedEffect
        db.collection("usuarios").document(uid).get().addOnSuccessListener { doc ->
            val userTiendaId = doc.getString("tiendaId")
            val userName = doc.getString("nombre") ?: "Usuario"
            if (userTiendaId != null) {
                currentStoreId = userTiendaId
                refreshData(userTiendaId)
            } else {
                // Fallback
                db.collection("tiendas").whereEqualTo("adminUid", userName).get().addOnSuccessListener { adminRes ->
                    if (!adminRes.isEmpty) {
                        currentStoreId = adminRes.documents[0].id
                        currentStoreId?.let { refreshData(it) }
                    } else {
                        db.collectionGroup("personal").whereEqualTo("uid", userName).get().addOnSuccessListener { workerRes ->
                            if (!workerRes.isEmpty) {
                                currentStoreId = workerRes.documents[0].reference.parent.parent?.id
                                currentStoreId?.let { refreshData(it) }
                            }
                        }
                    }
                }
            }
        }
    }

    LaunchedEffect(selectedCategory, selectedStatus, searchQuery, allProducts) {
        filteredProducts = allProducts.filter { p ->
            val matchesCat = selectedCategory == "Todas" || p.categoria == selectedCategory
            val matchesStat = selectedStatus == "Todos" || p.statusText == selectedStatus
            val matchesSearch = p.nombre.contains(searchQuery, ignoreCase = true)
            matchesCat && matchesStat && matchesSearch
        }
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            ProductosActivityBinding.inflate(LayoutInflater.from(ctx)).apply {
                etSearch.addTextChangedListener(object : TextWatcher {
                    override fun afterTextChanged(s: Editable?) { searchQuery = s?.toString() ?: "" }
                    override fun beforeTextChanged(s: CharSequence?, st: Int, co: Int, af: Int) {}
                    override fun onTextChanged(s: CharSequence?, st: Int, be: Int, co: Int) {}
                })
                btnCategoria.setOnClickListener { view ->
                    val p = PopupMenu(ctx, view)
                    listOf("Todas", "Frutas y Verduras", "Carnes y Mariscos", "Refrigerados", "Congelados", "Panadería", "Abarrotes", "Bebidas", "Snacks y Dulces", "Limpieza del Hogar", "Higiene Personal", "Salud y Farmacia", "Bebés", "Mascotas", "Ferretería", "Hogar", "Electrónica", "Papelería y Oficina", "Ropa y Accesorios", "Licores y Cervezas").forEach { p.menu.add(it) }
                    p.setOnMenuItemClickListener { selectedCategory = it.title.toString(); btnCategoria.text = "Categoría: $selectedCategory"; true }
                    p.show()
                }
                btnStatusFilter.setOnClickListener { view ->
                    val p = PopupMenu(ctx, view)
                    listOf("Todos", "Buen estado", "Por vencer", "Vencido").forEach { p.menu.add(it) }
                    p.setOnMenuItemClickListener { selectedStatus = it.title.toString(); btnStatusFilter.text = "Estado: $selectedStatus"; true }
                    p.show()
                }
                bottomNavigationView.selectedItemId = R.id.nav_productos
                bottomNavigationView.setOnItemSelectedListener { item ->
                    when (item.itemId) {
                        R.id.nav_home -> { navController.navigate("home"); true }
                        R.id.nav_escanear -> { navController.navigate("scan"); true }
                        R.id.nav_calendario -> { navController.navigate("calendar"); true }
                        else -> true
                    }
                }
            }.root
        },
        update = { root ->
            val b = ProductosActivityBinding.bind(root)
            b.llProductList.removeAllViews()
            if (filteredProducts.isEmpty()) {
                b.tvEmptyMessage.visibility = View.VISIBLE
                b.tvEmptyMessage.text = if (allProducts.isEmpty()) "Inventario vacío." else "Sin coincidencias."
            } else {
                b.tvEmptyMessage.visibility = View.GONE
                val inflater = LayoutInflater.from(b.root.context)
                filteredProducts.forEach { product ->
                    val itemBinding = ItemProductoBinding.inflate(inflater, b.llProductList, false)
                    val isExpanded = expandedProductId == product.id
                    itemBinding.tvProductName.text = "${product.nombre} (${product.cantidad})"
                    itemBinding.tvProductInfo.text = "${product.categoria}\nVence: ${product.fechaVencimiento}"
                    itemBinding.tvProductStatus.text = product.statusText
                    itemBinding.tvProductStatus.setBackgroundColor(Color.parseColor(product.statusColor))
                    if (product.bitmap != null) itemBinding.ivProductImage.setImageBitmap(product.bitmap)
                    else itemBinding.ivProductImage.setImageResource(android.R.drawable.ic_menu_gallery)
                    
                    itemBinding.layoutExpandedInfo.visibility = if (isExpanded) View.VISIBLE else View.GONE
                    itemBinding.ivExpandArrow.rotation = if (isExpanded) 180f else 0f
                    
                    if (isExpanded) {
                        itemBinding.tvDetailCategory.text = product.categoria
                        itemBinding.tvDetailBrand.text = product.marca
                        itemBinding.tvDetailPresentation.text = product.presentacion
                        itemBinding.tvDetailRegDate.text = product.fechaRegistro
                        itemBinding.tvDetailExpDate.text = product.fechaVencimiento
                        itemBinding.tvDetailStatus.text = product.statusText
                        itemBinding.vStatusDot.backgroundTintList = ColorStateList.valueOf(Color.parseColor(product.statusColor))
                        itemBinding.tvDetailQuantity.text = "${product.cantidad} unidades"
                        
                        itemBinding.btnEditProduct.setOnClickListener {
                            navController.navigate("add_product?productId=${product.id}")
                        }
                        
                        itemBinding.btnDeleteProduct.setOnClickListener {
                            currentStoreId?.let { sid ->
                                db.collection("tiendas").document(sid).collection("productos").document(product.id).delete().addOnSuccessListener {
                                    NotificationHelper.cancelProductNotifications(b.root.context, product.nombre)
                                    Toast.makeText(b.root.context, "Eliminado", Toast.LENGTH_SHORT).show()
                                    refreshData(sid)
                                }
                            }
                        }
                    }
                    itemBinding.layoutMainInfo.setOnClickListener { expandedProductId = if (isExpanded) null else product.id }
                    b.llProductList.addView(itemBinding.root)
                }
            }
        }
    )
}
