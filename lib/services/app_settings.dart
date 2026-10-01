import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';

/// Preferencias de la app que cambian su aspecto: modo oscuro/claro e idioma.
///
/// Se guardan en el teléfono. Al cambiarlas, [revision] avisa a `ZentoryApp`
/// para que vuelva a dibujar todas las pantallas sin perder la navegación.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _prefDarkMode = 'dark_mode';
  static const _prefLanguage = 'language';

  /// Cambia cada vez que se modifica una preferencia.
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get isDark => AppColors.isDark;
  AppLanguage get language => currentLanguage;

  /// Carga las preferencias guardadas (modo oscuro y español por defecto).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      AppColors.isDark = prefs.getBool(_prefDarkMode) ?? true;
      final code = prefs.getString(_prefLanguage);
      currentLanguage = AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.es,
      );
    } catch (_) {
      // Sin preferencias guardadas se usan los valores por defecto.
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (AppColors.isDark == value) return;
    AppColors.isDark = value;
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkMode, value);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (currentLanguage == value) return;
    currentLanguage = value;
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguage, value.code);
  }
}
