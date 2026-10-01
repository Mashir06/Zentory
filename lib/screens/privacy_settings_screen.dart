import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';
import '../l10n/strings.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final email = AuthService.instance.currentUser?.email;
    if (email == null) {
      showMessage(context, tr('No se pudo obtener el correo del usuario'));
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (context.mounted) {
        showMessage(
          context,
          tr('Se ha enviado un correo para restablecer tu contraseña a {0}', [email]),
          long: true,
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              SimpleHeader(title: tr('Privacidad y Seguridad')),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    settingsSectionTitle(tr('Seguridad de la cuenta')),
                    SettingsOption(
                      icon: Icons.key_outlined,
                      title: tr('Cambiar Contraseña'),
                      subtitle: tr('Recibirás un correo para restablecerla'),
                      onTap: () => _changePassword(context),
                    ),
                    SettingsOption(
                      icon: Icons.verified_user_outlined,
                      title: tr('Estado de la cuenta'),
                      subtitle: tr('Tu cuenta está protegida por Zentory'),
                    ),
                    settingsSectionTitle(tr('Datos personales')),
                    SettingsOption(
                      icon: Icons.delete_forever_outlined,
                      iconColor: AppColors.danger,
                      titleColor: AppColors.danger,
                      title: tr('Eliminar mi cuenta'),
                      onTap: () => showMessage(
                        context,
                        tr('Opción no disponible en esta versión'),
                      ),
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
