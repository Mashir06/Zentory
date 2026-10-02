import 'package:flutter/material.dart';

/// Paleta de Zentory (tomada de los layouts XML de la app Kotlin).
///
/// Los colores de fondo, superficies y textos cambian según el modo elegido
/// en Ajustes ([isDark]); los colores de marca y de estado son los mismos en
/// los dos modos.
class AppColors {
  AppColors._();

  /// Modo oscuro (predeterminado) o claro. Lo cambia `AppSettings`.
  static bool isDark = true;

  static Color _pick(int dark, int light) => Color(isDark ? dark : light);

  static Color get background => _pick(0xFF0F172A, 0xFFF1F5F9);
  static Color get backgroundTop => _pick(0xFF0B0F1A, 0xFFFFFFFF);
  static Color get backgroundBottom => _pick(0xFF020617, 0xFFE2E8F0);

  static Color get surface => _pick(0xFF1E293B, 0xFFFFFFFF);
  static Color get surfaceAlt => _pick(0xFF24345F, 0xFFE0E7FF);
  static Color get border => _pick(0xFF334155, 0xFFCBD5E1);

  static Color get textPrimary => _pick(0xFFFFFFFF, 0xFF0F172A);
  static Color get textSecondary => _pick(0xFF94A3B8, 0xFF475569);
  static Color get textMuted => _pick(0xFF475569, 0xFF94A3B8);
  static Color get textSoft => _pick(0xFFCBD5E1, 0xFF334155);

  /// Texto e íconos sobre colores fuertes (verde, rojo, café): siempre blanco.
  static const onColor = Colors.white;

  static const primary = Color(0xFF10B981); // verde Zentory
  // En modo claro se invierten: fondo verde suave con texto verde oscuro.
  static Color get primaryDark => _pick(0xFF065F46, 0xFFD1FAE5);
  static Color get primaryLight => _pick(0xFFD1FAE5, 0xFF065F46);
  static const warning = Color(0xFFF59E0B);
  static const amber = Color(0xFFFFC107);
  static const danger = Color(0xFFEF4444);
  static const dangerBright = Color(0xFFFF3B3B);
  static const info = Color(0xFF6F8CFF);
  static const blue = Color(0xFF3B82F6);
  static const alertBrown = Color(0xFF9A4A0D);
  static const whatsapp = Color(0xFF25D366);

  /// Logo: en modo claro se usa la versión con las letras oscuras.
  static String get logoAsset => isDark
      ? 'assets/images/logozentory.png'
      : 'assets/images/logozentory_light.png';

  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, background, backgroundBottom],
      );
}
