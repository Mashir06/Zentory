import 'dart:typed_data';

import '../utils/date_utils.dart';
import 'product.dart';
import '../l10n/strings.dart';

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
  if (expiry == null) return tr('Sin fecha de vencimiento');
  final d = DateUtilsZ.daysFromToday(expiry);
  if (d < 0) return d == -1 ? tr('Venció ayer') : tr('Venció hace {0} días', [-d]);
  if (d == 0) return tr('Vence hoy');
  if (d == 1) return tr('Vence mañana');
  return tr('Vence en {0} días', [d]);
}

/// Número de lote para mostrar: L001, L002...
String lotLabel(int index) => 'L${index.toString().padLeft(3, '0')}';

/// Código del registro en Firestore, para distinguir lotes con precisión.
String lotCode(Product p) {
  final id = p.id;
  return '#${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';
}

/// Clave que identifica a un producto: su código de barras. Así puede haber
/// varios productos con el mismo nombre (p. ej. Coca-Cola en distintos
/// tamaños). Los productos antiguos sin código se identifican por el nombre
/// (sin mayúsculas ni espacios extremos).
String productKey(String nombre, String? codigoBarras) {
  final code = codigoBarras?.trim() ?? '';
  if (code.isNotEmpty) return 'c:$code';
  return nombre.trim().toLowerCase();
}

/// Clave de agrupación de un lote.
String groupKeyOf(Product p) {
  final key = productKey(p.nombre, p.codigoBarras);
  return key.isEmpty ? 'id:${p.id}' : key;
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
/// después. Puede no tener lotes todavía (producto recién creado en el
/// catálogo); en ese caso [info] trae su nombre, presentación y foto.
class ProductGroup {
  ProductGroup(this.key, List<Product> lots, {this.info})
      : lots = [...lots]..sort(compareByExpiry),
        status = lots.isEmpty
            ? null
            : lots
                .map((l) => l.status)
                .reduce((a, b) => statusRank(a) >= statusRank(b) ? a : b),
        totalQty = lots.fold<num>(0, (sum, l) => sum + qtyOf(l));

  final String key;
  final List<Product> lots;

  /// Ficha del catálogo, si existe.
  final CatalogItem? info;

  /// Estado general (el del lote en peor situación); `null` si no hay lotes.
  final ProductStatus? status;
  final num totalQty;

  bool get hasLots => lots.isNotEmpty;

  /// Lote que vence antes (solo si hay lotes).
  Product? get first => lots.isEmpty ? null : lots.first;

  String get nombre => info?.nombre ?? first?.nombre ?? '';

  /// Código de barras del producto, si tiene.
  String? get codigoBarras {
    final fromInfo = info?.codigoBarras ?? '';
    if (fromInfo.isNotEmpty) return fromInfo;
    for (final l in lots) {
      final c = l.codigoBarras ?? '';
      if (c.isNotEmpty) return c;
    }
    return null;
  }

  String get presentacion {
    final fromInfo = info?.presentacion.trim() ?? '';
    if (fromInfo.isNotEmpty && fromInfo != 'N/A') return fromInfo;
    for (final l in lots) {
      final p = l.presentacion.trim();
      if (p.isNotEmpty && p != 'N/A') return p;
    }
    return '';
  }

  String? get imagenBase64 {
    final fromInfo = info?.imagenBase64;
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    for (final l in lots) {
      if (l.imagenBase64 != null && l.imagenBase64!.isNotEmpty) {
        return l.imagenBase64;
      }
    }
    return null;
  }

  Uint8List? get imageBytes {
    if (info?.imageBytes != null) return info!.imageBytes;
    for (final l in lots) {
      if (l.imageBytes != null) return l.imageBytes;
    }
    return null;
  }

  /// Fecha de vencimiento más próxima entre los lotes.
  DateTime? get nextExpiry => first?.expiryDate;
}

/// Agrupa una lista de registros (lotes) en productos. Si se pasa el
/// [catalog], se incluyen también los productos que aún no tienen lotes.
List<ProductGroup> groupProducts(
  Iterable<Product> products, {
  Iterable<CatalogItem> catalog = const [],
}) {
  final map = <String, List<Product>>{};
  for (final p in products) {
    map.putIfAbsent(groupKeyOf(p), () => []).add(p);
  }
  final infos = <String, CatalogItem>{};
  for (final c in catalog) {
    final key = productKey(c.nombre, c.codigoBarras);
    if (key.isEmpty) continue;
    infos.putIfAbsent(key, () => c);
    map.putIfAbsent(key, () => []);
  }
  return [
    for (final e in map.entries)
      ProductGroup(e.key, e.value, info: infos[e.key]),
  ];
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
