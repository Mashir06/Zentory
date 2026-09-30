import 'product.dart';
import '../utils/date_utils.dart';

/// Agrupación de productos en lotes.
///
/// En Firestore cada registro de `productos` tiene su propia fecha de
/// vencimiento y cantidad. Los registros con el mismo nombre se muestran como
/// **un producto con varios lotes**. Es solo presentación: no cambia los datos.
/// La usan las pantallas Productos y Calendario para numerar igual los lotes.

/// Prioridad de un estado (el lote "peor" manda):
/// vencido > por vencer > sin fecha > buen estado.
int statusRank(ProductStatus s) {
  switch (s) {
    case ProductStatus.expired:
      return 3;
    case ProductStatus.expiring:
      return 2;
    case ProductStatus.noDate:
      return 1;
    case ProductStatus.good:
      return 0;
  }
}

/// Cantidad numérica de un registro (el campo se guarda como texto).
num qtyOf(Product p) {
  final raw = p.cantidad.trim().replaceAll(',', '.');
  return int.tryParse(raw) ?? double.tryParse(raw) ?? 0;
}

String formatQty(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// Texto relativo de vencimiento: "Vence en 3 días", "Venció hace 2 días"...
String relativeExpiry(DateTime? expiry) {
  if (expiry == null) return 'Sin fecha de vencimiento';
  final d = DateUtilsZ.daysFromToday(expiry);
  if (d < 0) return d == -1 ? 'Venció ayer' : 'Venció hace ${-d} días';
  if (d == 0) return 'Vence hoy';
  if (d == 1) return 'Vence mañana';
  return 'Vence en $d días';
}

/// Número de lote para mostrar: L001, L002...
String lotLabel(int index) => 'L${index.toString().padLeft(3, '0')}';

/// Código del registro en Firestore, para distinguir lotes con precisión.
String lotCode(Product p) {
  final id = p.id;
  return '#${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';
}

/// Clave de agrupación: el nombre del producto sin mayúsculas ni espacios
/// extremos.
String groupKeyOf(Product p) {
  final name = p.nombre.trim().toLowerCase();
  return name.isEmpty ? 'id:${p.id}' : name;
}

int compareByExpiry(Product a, Product b) {
  final ea = a.expiryDate;
  final eb = b.expiryDate;
  if (ea == null && eb == null) return 0;
  if (ea == null) return 1;
  if (eb == null) return -1;
  return ea.compareTo(eb);
}

/// Un producto con sus lotes, ordenados del que vence antes al que vence
/// después.
class ProductGroup {
  ProductGroup(this.key, List<Product> lots)
      : lots = [...lots]..sort(compareByExpiry),
        status = lots
            .map((l) => l.status)
            .reduce((a, b) => statusRank(a) >= statusRank(b) ? a : b),
        totalQty = lots.fold<num>(0, (sum, l) => sum + qtyOf(l));

  final String key;
  final List<Product> lots;
  final ProductStatus status;
  final num totalQty;

  Product get main => lots.first;
  String get nombre => main.nombre;

  /// Primer lote con foto, para la miniatura del producto.
  Product get withImage =>
      lots.firstWhere((l) => l.imageBytes != null, orElse: () => main);

  /// Fecha de vencimiento más próxima entre los lotes.
  DateTime? get nextExpiry => main.expiryDate;

  String get categoria => lots.map((l) => l.categoria).toSet().join(', ');
}

/// Agrupa una lista de registros en productos (sin ordenar los grupos).
List<ProductGroup> groupProducts(Iterable<Product> products) {
  final map = <String, List<Product>>{};
  for (final p in products) {
    map.putIfAbsent(groupKeyOf(p), () => []).add(p);
  }
  return [for (final e in map.entries) ProductGroup(e.key, e.value)];
}

/// Etiqueta de lote (L001, L002...) de cada registro, calculada sobre el
/// inventario completo para que no cambie al filtrar o al ver otra pantalla.
Map<String, String> lotLabels(Iterable<Product> allProducts) {
  final labels = <String, String>{};
  for (final g in groupProducts(allProducts)) {
    for (var i = 0; i < g.lots.length; i++) {
      labels[g.lots[i].id] = lotLabel(i + 1);
    }
  }
  return labels;
}
