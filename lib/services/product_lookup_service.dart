import 'dart:convert';

import 'package:http/http.dart' as http;

/// Datos de un producto obtenidos al escanear su código de barras.
class ScannedProduct {
  ScannedProduct({
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.presentacion,
  });

  final String nombre;
  final String categoria;
  final String marca;
  final String presentacion;
}

/// Consulta la base pública de OpenFoodFacts (igual que la app Kotlin).
class ProductLookupService {
  ProductLookupService._();

  /// Devuelve `null` si el producto no está en OpenFoodFacts.
  static Future<ScannedProduct?> lookup(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v0/product/$barcode.json',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': 'Zentory/1.0 (Android)'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Error al obtener datos (${response.statusCode})');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map || json['status'] != 1) return null;
    final product = json['product'];
    if (product is! Map) return null;

    String field(String key, String fallback) {
      final value = product[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return fallback;
    }

    final categories = field('categories', '');
    final firstCategory = categories.split(',').first.trim();

    return ScannedProduct(
      nombre: field('product_name', 'Producto Desconocido'),
      categoria: firstCategory.isEmpty ? 'Otros' : firstCategory,
      marca: field('brands', 'N/A'),
      presentacion: field('quantity', 'N/A'),
    );
  }
}
