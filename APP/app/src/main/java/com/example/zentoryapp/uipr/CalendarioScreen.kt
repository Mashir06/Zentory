package com.example.zentoryapp.uipr

import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.util.Log
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.R
import com.example.zentoryapp.databinding.CalendarioActivityBinding
import com.example.zentoryapp.databinding.ItemProductoBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.text.SimpleDateFormat
import java.util.*

fun parseSafeColor(colorStr: String?): Int {
    return try {
        Color.parseColor(colorStr ?: "#94A3B8")
    } catch (e: Exception) {
        Color.parseColor("#94A3B8")
    }
}

@Composable
fun CalendarioScreen(navController: NavController) {
    val db = remember { FirebaseFirestore.getInstance() }
    val auth = remember { FirebaseAuth.getInstance() }
    
    var currentCalendar by remember { mutableStateOf(Calendar.getInstance()) }
    var selectedDate by remember { mutableStateOf(Calendar.getInstance()) }
    var allProducts by remember { mutableStateOf(listOf<ProductItem>()) }
    var isShowingAll by remember { mutableStateOf(false) }
    var isShowingMonth by remember { mutableStateOf(true) }
    
    val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale("es", "ES"))
    val dayFormat = SimpleDateFormat("d/M/yyyy", Locale.getDefault())

    // Cargar datos
    LaunchedEffect(auth.currentUser) {
        val uid = auth.currentUser?.uid ?: return@LaunchedEffect
        
        db.collection("usuarios").document(uid).get().addOnSuccessListener { doc ->
            val userTiendaId = doc.getString("tiendaId")
            val userName = doc.getString("nombre") ?: "Usuario"
            if (userTiendaId != null) {
                fetchProductsFromStore(db, userTiendaId) { allProducts = it }
            } else {
                // Fallback
                db.collection("tiendas").whereEqualTo("adminUid", userName).get().addOnSuccessListener { adminRes ->
                    if (!adminRes.isEmpty) {
                        val storeId = adminRes.documents[0].id
                        fetchProductsFromStore(db, storeId) { allProducts = it }
                    } else {
                        db.collectionGroup("personal").whereEqualTo("uid", userName).get().addOnSuccessListener { workerRes ->
                            if (!workerRes.isEmpty) {
                                val workerStoreId = workerRes.documents[0].reference.parent.parent?.id
                                workerStoreId?.let { fetchProductsFromStore(db, it) { allProducts = it } }
                            }
                        }
                    }
                }
            }
        }
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val binding = CalendarioActivityBinding.inflate(LayoutInflater.from(ctx))
            binding.bottomNavigationView.selectedItemId = R.id.nav_calendario
            binding.root
        },
        update = { root ->
            val b = CalendarioActivityBinding.bind(root)
            val context = b.root.context
            
            // 1. Month Selector
            b.monthTitle.text = monthYearFormat.format(currentCalendar.time).replaceFirstChar { it.uppercase() }
            b.btnPrevMonth.setOnClickListener {
                val newCal = currentCalendar.clone() as Calendar
                newCal.add(Calendar.MONTH, -1)
                currentCalendar = newCal
                isShowingMonth = true
                isShowingAll = false
            }
            b.btnNextMonth.setOnClickListener {
                val newCal = currentCalendar.clone() as Calendar
                newCal.add(Calendar.MONTH, 1)
                currentCalendar = newCal
                isShowingMonth = true
                isShowingAll = false
            }

            // 2. Render Calendar Grid
            renderCalendarGrid(b, currentCalendar, selectedDate, allProducts) { newDate ->
                selectedDate = newDate
                isShowingAll = false
                isShowingMonth = false
            }

            // 3. Alert Card
            val todayStr = dayFormat.format(Calendar.getInstance().time)
            val productsToday = allProducts.count { it.fechaVencimiento == todayStr }
            if (productsToday > 0) {
                b.alertCard.visibility = View.VISIBLE
                b.tvAlertTitle.text = if (productsToday == 1) "1 producto vence hoy" else "$productsToday productos vencen hoy"
            } else {
                b.alertCard.visibility = View.GONE
            }

            // 4. Header
            val selectedDateStr = dayFormat.format(selectedDate.time)
            b.tvSelectedDateHeader.text = when {
                isShowingAll -> "Todos los productos"
                isShowingMonth -> "Productos de ${monthYearFormat.format(currentCalendar.time).replaceFirstChar { it.uppercase() }}"
                else -> "Productos para el ${SimpleDateFormat("d 'de' MMMM", Locale("es", "ES")).format(selectedDate.time)}"
            }

            // 5. Product List
            b.llProductList.removeAllViews()
            val filteredList = when {
                isShowingAll -> allProducts
                isShowingMonth -> allProducts.filter { product ->
                    try {
                        val date = dayFormat.parse(product.fechaVencimiento)
                        val cal = Calendar.getInstance().apply { time = date!! }
                        cal.get(Calendar.MONTH) == currentCalendar.get(Calendar.MONTH) &&
                                cal.get(Calendar.YEAR) == currentCalendar.get(Calendar.YEAR)
                    } catch (e: Exception) { false }
                }
                else -> allProducts.filter { it.fechaVencimiento == selectedDateStr }
            }
            
            if (filteredList.isEmpty()) {
                val emptyTv = TextView(context).apply {
                    text = "No hay productos que venzan en esta fecha"
                    setTextColor(Color.parseColor("#94A3B8"))
                    textAlignment = View.TEXT_ALIGNMENT_CENTER
                    setPadding(0, 60, 0, 60)
                }
                b.llProductList.addView(emptyTv)
            } else {
                val inflater = LayoutInflater.from(context)
                filteredList.forEach { product ->
                    val itemB = ItemProductoBinding.inflate(inflater, b.llProductList, false)
                    itemB.tvProductName.text = "${product.nombre} (${product.cantidad})"
                    itemB.tvProductInfo.text = "${product.categoria} | Marca: ${product.marca}"
                    itemB.tvProductStatus.text = product.statusText
                    itemB.tvProductStatus.setBackgroundColor(parseSafeColor(product.statusColor))
                    
                    if (product.bitmap != null) itemB.ivProductImage.setImageBitmap(product.bitmap)
                    else itemB.ivProductImage.setImageResource(android.R.drawable.ic_menu_gallery)
                    
                    // Llenar detalles expandibles
                    try {
                        itemB.tvDetailCategory.text = product.categoria
                        itemB.tvDetailBrand.text = product.marca
                        itemB.tvDetailPresentation.text = product.presentacion
                        itemB.tvDetailRegDate.text = product.fechaRegistro
                        itemB.tvDetailExpDate.text = product.fechaVencimiento
                        itemB.tvDetailQuantity.text = "${product.cantidad} unidades"
                        itemB.tvDetailStatus.text = product.statusText
                        itemB.vStatusDot.backgroundTintList = ColorStateList.valueOf(parseSafeColor(product.statusColor))

                        // Ocultar botones de editar/eliminar (solo lectura)
                        itemB.btnEditProduct.visibility = View.GONE
                        itemB.btnDeleteProduct.visibility = View.GONE

                        itemB.root.setOnClickListener {
                            val isExpanded = itemB.layoutExpandedInfo.visibility == View.VISIBLE
                            itemB.layoutExpandedInfo.visibility = if (isExpanded) View.GONE else View.VISIBLE
                            itemB.ivExpandArrow.animate().rotation(if (isExpanded) 0f else 180f).setDuration(200).start()
                        }
                    } catch (e: Exception) {
                        Log.e("CalendarioScreen", "Error setting product details: ${e.message}")
                    }
                    b.llProductList.addView(itemB.root)
                }
            }

            b.btnVerTodos.setOnClickListener {
                isShowingAll = true
                isShowingMonth = false
            }

            // Navigation
            b.bottomNavigationView.setOnItemSelectedListener {
                when (it.itemId) {
                    R.id.nav_home -> { if(navController.currentDestination?.route != "home") navController.navigate("home"); true }
                    R.id.nav_productos -> { if(navController.currentDestination?.route != "productos") navController.navigate("productos"); true }
                    R.id.nav_escanear -> { if(navController.currentDestination?.route != "scan") navController.navigate("scan"); true }
                    else -> true
                }
            }
        }
    )
}

private fun fetchProductsFromStore(db: FirebaseFirestore, storeId: String, onResult: (List<ProductItem>) -> Unit) {
    db.collection("tiendas").document(storeId).collection("productos").get().addOnSuccessListener { result ->
            val products = result.map { doc ->
                val fechaStr = doc.getString("fechaVencimiento") ?: ""
                val regTs = doc.getTimestamp("fechaRegistro")
                val regDateStr = if (regTs != null) sdf.format(regTs.toDate()) else doc.getString("fechaRegistro") ?: "N/A"
                val imgBase64 = doc.getString("imagen")
                val bitmap = if (!imgBase64.isNullOrEmpty()) base64ToBitmap(imgBase64) else null
                
                val status = try {
                    val date = sdf.parse(fechaStr)
                    val now = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
                    val diff = if (date != null) (date.time - now) / (1000 * 60 * 60 * 24) else 99
                    when {
                        diff < 1 -> Pair("Vencido", "#EF4444")
                        diff <= 7 -> Pair("Por vencer", "#F59E0B")
                        else -> Pair("Buen estado", "#10B981")
                    }
                } catch (_: Exception) { Pair("Sin fecha", "#94A3B8") }

                ProductItem(
                    id = doc.id,
                    nombre = doc.getString("nombre") ?: "",
                    categoria = doc.getString("categoria") ?: "Otros",
                    marca = doc.getString("marca") ?: "N/A",
                    presentacion = doc.getString("presentacion") ?: "N/A",
                    fechaVencimiento = fechaStr,
                    fechaRegistro = regDateStr,
                    cantidad = doc.getString("cantidad") ?: "0",
                    statusText = status.first,
                    statusColor = status.second,
                    bitmap = bitmap
                )
            }
        onResult(products)
    }
}

private fun renderCalendarGrid(
    b: CalendarioActivityBinding,
    currentCal: Calendar,
    selectedCal: Calendar,
    products: List<ProductItem>,
    onDateSelected: (Calendar) -> Unit
) {
    val dayFormat = SimpleDateFormat("d/M/yyyy", Locale.getDefault())
    val tempCal = currentCal.clone() as Calendar
    tempCal.set(Calendar.DAY_OF_MONTH, 1)
    
    val firstDayOfWeek = tempCal.get(Calendar.DAY_OF_WEEK)
    val offset = if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2
    tempCal.add(Calendar.DAY_OF_MONTH, -offset)

    val dayTextViews = mutableListOf<TextView>()
    val dayContainers = mutableListOf<View>()

    val gridContainer = b.calendarGridContainer
    for (i in 0 until gridContainer.childCount) {
        val row = gridContainer.getChildAt(i) as? LinearLayout ?: continue
        if (i == 0) continue
        
        for (j in 0 until row.childCount) {
            val cell = row.getChildAt(j)
            if (cell is FrameLayout) {
                val tv = cell.getChildAt(1) as? TextView
                if (tv != null) {
                    dayTextViews.add(tv)
                    dayContainers.add(cell)
                }
            }
        }
    }

    for (i in 0 until dayTextViews.size) {
        if (i >= 42) break
        
        val tv = dayTextViews[i]
        val container = dayContainers[i] as FrameLayout
        val dayNum = tempCal.get(Calendar.DAY_OF_MONTH)
        val isCurrentMonth = tempCal.get(Calendar.MONTH) == currentCal.get(Calendar.MONTH)
        val dateStr = dayFormat.format(tempCal.time)
        val isSelected = dayFormat.format(selectedCal.time) == dateStr
        
        tv.text = dayNum.toString()
        tv.setTextColor(if (isCurrentMonth) Color.WHITE else Color.parseColor("#475569"))
        
        // Background selector
        container.getChildAt(0)?.visibility = if (isSelected) View.VISIBLE else View.GONE

        // Indicators
        val productsOnDate = products.filter { it.fechaVencimiento == dateStr }
        val dot = container.getChildAt(2)
        if (dot != null) {
            if (productsOnDate.isNotEmpty()) {
                dot.visibility = View.VISIBLE
                // Prioridad de color: Rojo (Vencido) > Naranja (Por vencer) > Verde (Buen estado)
                val color = when {
                    productsOnDate.any { it.statusText == "Vencido" } -> "#EF4444"
                    productsOnDate.any { it.statusText == "Por vencer" } -> "#F59E0B"
                    else -> "#10B981"
                }
                dot.backgroundTintList = ColorStateList.valueOf(parseSafeColor(color))
                tv.setTextColor(parseSafeColor(color))
            } else {
                dot.visibility = View.GONE
            }
        }

        val clickedDate = tempCal.clone() as Calendar
        container.setOnClickListener { onDateSelected(clickedDate) }
        tempCal.add(Calendar.DAY_OF_MONTH, 1)
    }
}
