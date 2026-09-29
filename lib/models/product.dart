import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/image_utils.dart';

enum ProductStatus {
  good('Buen estado', AppColors.primary),
  expiring('Por vencer', AppColors.warning),
  expired('Vencido', AppColors.danger),
  noDate('Sin fecha', AppColors.textSecondary);

  const ProductStatus(this.label, this.color);
  final String label;
  final Color color;

  /// Vencido si faltan 0 días o menos, por vencer si faltan 7 o menos.
  static ProductStatus fromExpiry(DateTime? expiry) {
    if (expiry == null) return ProductStatus.noDate;
    final diff = DateUtilsZ.daysFromToday(expiry);
    if (diff <= 0) return ProductStatus.expired;
    if (diff <= 7) return ProductStatus.expiring;
    return ProductStatus.good;
  }
}

/// Producto del inventario de una tienda
/// (`tiendas/{tiendaId}/productos/{id}` en Firestore).
class Product {
  Product({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.presentacion,
    required this.fechaVencimiento,
    required this.fechaRegistro,
    required this.cantidad,
    this.imagenBase64,
  })  : expiryDate = DateUtilsZ.parse(fechaVencimiento),
        imageBytes = ImageUtils.decode(imagenBase64);

  final String id;
  final String nombre;
  final String categoria;
  final String marca;
  final String presentacion;

  /// Texto `d/M/yyyy`, tal como se guarda en Firestore.
  final String fechaVencimiento;
  final String fechaRegistro;
  final String cantidad;
  final String? imagenBase64;

  final DateTime? expiryDate;
  final Uint8List? imageBytes;

  ProductStatus get status => ProductStatus.fromExpiry(expiryDate);

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final reg = data['fechaRegistro'];
    String regStr;
    if (reg is Timestamp) {
      regStr = DateUtilsZ.format(reg.toDate());
    } else if (reg is String && reg.isNotEmpty) {
      regStr = reg;
    } else {
      regStr = 'N/A';
    }
    return Product(
      id: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      categoria: (data['categoria'] ?? 'Otros').toString(),
      marca: (data['marca'] ?? 'N/A').toString(),
      presentacion: (data['presentacion'] ?? 'N/A').toString(),
      fechaVencimiento: (data['fechaVencimiento'] ?? '').toString(),
      fechaRegistro: regStr,
      cantidad: (data['cantidad'] ?? '0').toString(),
      imagenBase64: data['imagen'] as String?,
    );
  }
}

/// Entrada del catálogo de productos frecuentes
/// (`tiendas/{tiendaId}/catalogo/{nombre}`).
class CatalogItem {
  CatalogItem({
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.presentacion,
    this.imagenBase64,
  }) : imageBytes = ImageUtils.decode(imagenBase64);

  final String nombre;
  final String categoria;
  final String marca;
  final String presentacion;
  final String? imagenBase64;
  final Uint8List? imageBytes;

  factory CatalogItem.fromMap(Map<String, dynamic> data) => CatalogItem(
        nombre: (data['nombre'] ?? 'N/A').toString(),
        categoria: (data['categoria'] ?? 'Otros').toString(),
        marca: (data['marca'] ?? 'N/A').toString(),
        presentacion: (data['presentacion'] ?? 'N/A').toString(),
        imagenBase64: data['imagen'] as String?,
      );
}
