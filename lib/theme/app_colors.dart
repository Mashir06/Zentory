import 'package:flutter/material.dart';

/// Paleta de Zentory (tomada de los layouts XML de la app Kotlin).
class AppColors {
  AppColors._();

  static const background = Color(0xFF0F172A);
  static const backgroundTop = Color(0xFF0B0F1A);
  static const backgroundBottom = Color(0xFF020617);

  static const surface = Color(0xFF1E293B);
  static const surfaceAlt = Color(0xFF24345F);
  static const border = Color(0xFF334155);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const textSoft = Color(0xFFCBD5E1);

  static const primary = Color(0xFF10B981); // verde Zentory
  static const primaryDark = Color(0xFF065F46);
  static const primaryLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const amber = Color(0xFFFFC107);
  static const danger = Color(0xFFEF4444);
  static const dangerBright = Color(0xFFFF3B3B);
  static const info = Color(0xFF6F8CFF);
  static const blue = Color(0xFF3B82F6);
  static const alertBrown = Color(0xFF9A4A0D);
  static const whatsapp = Color(0xFF25D366);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, background, backgroundBottom],
  );
}
