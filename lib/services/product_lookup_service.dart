import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Datos de un producto obtenidos al escanear su código de barras.
class ScannedProduct {
  ScannedProduct({
    required this.nombre,
    required this.presentacion,
    this.imageUrl,
  });

  final String nombre;
  final String presentacion;
  final String? imageUrl;
}

/// Consulta la base pública de OpenFoodFacts para rellenar nombre y tamaño.
class ProductLookupService {
  ProductLookupService._();

  static const _headers = {'User-Agent': 'Zentory/1.0 (Android)'};

  /// Campos que se piden a la API (respuesta más pequeña y rápida).
  static const _fields = 'product_name,product_name_es,product_name_en,'
      'generic_name,generic_name_es,brands,quantity,product_quantity,'
      'product_quantity_unit,image_front_small_url,image_small_url';

  /// Variantes del código: algunos lectores devuelven UPC-A (12 dígitos) y la
  /// base guarda EAN-13 (con un 0 delante), o al revés.
  static List<String> barcodeVariants(String code) {
    final c = code.trim();
    final out = <String>[c];
    if (RegExp(r'^\d+$').hasMatch(c)) {
      if (c.length == 12) out.add('0$c');
      if (c.length == 13 && c.startsWith('0')) out.add(c.substring(1));
      if (c.length < 12) out.add(c.padLeft(13, '0'));
    }
    return out;
  }

  /// Devuelve `null` si el producto no está en OpenFoodFacts.
  static Future<ScannedProduct?> lookup(String barcode) async {
    for (final code in barcodeVariants(barcode)) {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/product/$code.json',
        {'fields': _fields},
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      // 404 = no existe; se prueba la siguiente variante.
      if (response.statusCode == 404) continue;
      if (response.statusCode != 200) {
        throw Exception('Error al obtener datos (${response.statusCode})');
      }
      final found = parse(jsonDecode(utf8.decode(response.bodyBytes)));
      if (found != null) return found;
    }
    return null;
  }

  /// Interpreta la respuesta de OpenFoodFacts. Prefiere el nombre en español
  /// y arma el tamaño con `quantity` o con cantidad + unidad.
  static ScannedProduct? parse(Object? json) {
    if (json is! Map || json['status'] != 1) return null;
    final product = json['product'];
    if (product is! Map) return null;

    String text(String key) {
      final v = product[key];
      return v is String ? v.trim() : '';
    }

    String firstOf(List<String> keys) {
      for (final k in keys) {
        final v = text(k);
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    // Si no hay nombre, se usa la marca como último recurso.
    var nombre = firstOf([
      'product_name_es',
      'product_name',
      'product_name_en',
      'generic_name_es',
      'generic_name',
    ]);
    final marca = text('brands').split(',').first.trim();
    if (nombre.isEmpty) nombre = marca;
    if (nombre.isEmpty) return null;

    var presentacion = text('quantity');
    if (presentacion.isEmpty) {
      final q = product['product_quantity'];
      final unit = text('product_quantity_unit');
      final qText = q is num
          ? (q == q.roundToDouble() ? q.toInt().toString() : q.toString())
          : (q is String ? q.trim() : '');
      if (qText.isNotEmpty && qText != '0') {
        presentacion = unit.isEmpty ? qText : '$qText $unit';
      }
    }

    final image = firstOf(['image_front_small_url', 'image_small_url']);
    return ScannedProduct(
      nombre: nombre,
      presentacion: presentacion,
      imageUrl: image.isEmpty ? null : image,
    );
  }

  /// Descarga la foto del producto (pequeña). `null` si no se puede.
  static Future<Uint8List?> downloadImage(String? url) async {
    if (url == null) return null;
    try {
      final r = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200 || r.bodyBytes.length > 400 * 1024) return null;
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
