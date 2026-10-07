import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// Solo en la versión web abierta desde un iPhone o iPad: explica cómo
/// instalar Zentory en la pantalla de inicio desde Safari.
class IosInstallHint extends StatelessWidget {
  const IosInstallHint({super.key});

  static bool get applies =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!applies) return SizedBox.shrink();
    return ZCard(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.ios_share, color: AppColors.info),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Instala Zentory en tu iPhone'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  tr('En Safari, toca Compartir y luego "Agregar a pantalla de inicio". Así se abre como una app.'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
