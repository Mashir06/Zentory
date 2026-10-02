import 'package:flutter/material.dart';

/// Rutas de la app (equivalen a las del NavHost de la app Kotlin).
class Routes {
  Routes._();

  static const session = '/';
  static const login = '/login';
  static const register = '/register';
  static const storeSelection = '/store_selection';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const calendar = '/calendar';
  static const scan = '/scan';
  static const productos = '/productos';
  static const profile = '/profile';
  static const settings = '/settings';
  static const help = '/help';
  static const faq = '/faq';
  static const privacySettings = '/privacy_settings';
  static const addProduct = '/add_product';
  static const lotForm = '/lot_form';

  /// Pestañas de la barra inferior (se muestran sin animación).
  static const tabs = {home, productos, calendar};

  /// Reemplaza toda la pila (equivale a `popUpTo(0)`).
  static void resetTo(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  /// Cambia de pestaña dejando siempre "Inicio" como base de la pila,
  /// para que el botón Atrás regrese al inicio.
  static void goToTab(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    final nav = Navigator.of(context);
    if (route == home) {
      var foundHome = false;
      nav.popUntil((r) {
        if (r.settings.name == home) foundHome = true;
        return r.settings.name == home || r.isFirst;
      });
      if (!foundHome) nav.pushReplacementNamed(home);
      return;
    }
    nav.pushNamedAndRemoveUntil(
      route,
      (r) => r.settings.name == home,
    );
  }
}

/// Argumentos del formulario de **producto** (nombre, foto y presentación).
class ProductFormArgs {
  const ProductFormArgs({
    this.editName,
    this.editCode,
    this.qrNombre,
    this.qrPresentacion,
  });

  /// Nombre del producto a editar; `null` para crear uno nuevo.
  final String? editName;

  /// Código de barras del producto a editar (lo identifica).
  final String? editCode;

  /// Datos obtenidos al escanear un código de barras.
  final String? qrNombre;
  final String? qrPresentacion;
}

/// Argumentos del formulario de **lote** (fecha de vencimiento y cantidad).
class LotFormArgs {
  const LotFormArgs({
    required this.nombre,
    this.presentacion = '',
    this.imagenBase64,
    this.codigoBarras,
    this.lotId,
    this.lotLabel,
  });

  /// Producto al que pertenece el lote.
  final String nombre;
  final String presentacion;
  final String? imagenBase64;
  final String? codigoBarras;

  /// ID del lote a editar; `null` para crear uno nuevo.
  final String? lotId;

  /// Número visible del lote (L001...), solo al editar.
  final String? lotLabel;
}

/// Permite que pantallas como "Inicio" recarguen sus datos al volver a ellas.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
