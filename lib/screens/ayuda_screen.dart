import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../routes.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';
import '../l10n/strings.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  static final _zentoryPage = Uri.parse('https://www.nubiksoft.com/zentory/');

  Future<void> _openZentoryPage() async {
    var ok = false;
    try {
      ok = await launchUrl(_zentoryPage, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      showMessage(context, tr('No se pudo abrir la página de Zentory'));
    }
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
                      onTap: _openZentoryPage,
                      trailing: Icon(Icons.open_in_new,
                          color: AppColors.textSecondary, size: 20),
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
