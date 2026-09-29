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

  /// Pestañas de la barra inferior (se muestran sin animación).
  static const tabs = {home, productos, scan, calendar};

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

/// Argumentos de la pantalla de registro/edición de productos.
class AddProductArgs {
  const AddProductArgs({
    this.productId,
    this.qrNombre,
    this.qrCategoria,
    this.qrMarca,
    this.qrPresentacion,
  });

  final String? productId;
  final String? qrNombre;
  final String? qrCategoria;
  final String? qrMarca;
  final String? qrPresentacion;
}

/// Permite que pantallas como "Inicio" recarguen sus datos al volver a ellas.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
