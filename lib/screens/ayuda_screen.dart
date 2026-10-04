import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/app_colors.dart';
import '../utils/support.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';
import '../l10n/strings.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  /// Soporte por WhatsApp (sin pasar por la web, que muestra precios).
  Future<void> _contactSupport() async {
    final ok = await openSupportWhatsApp(tr('Hola, necesito soporte técnico con Zentory.'));
    if (!ok && mounted) showMessage(context, tr('No se pudo abrir WhatsApp'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                subtitle: tr('Ayuda y Soporte'),
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text(
                      tr('¿En qué podemos ayudarte?'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    SettingsOption(
                      icon: Icons.quiz_outlined,
                      title: tr('Preguntas Frecuentes (FAQ)'),
                      onTap: () => Navigator.of(context).pushNamed(Routes.faq),
                    ),
                    SettingsOption(
                      icon: Icons.support_agent,
                      title: tr('Contactar Soporte'),
                      onTap: _contactSupport,
                      trailing: Icon(Icons.chat_outlined,
                          color: AppColors.whatsapp, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
