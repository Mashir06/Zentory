import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final email = AuthService.instance.currentUser?.email;
    if (email == null) {
      showMessage(context, 'No se pudo obtener el correo del usuario');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (context.mounted) {
        showMessage(
          context,
          'Se ha enviado un correo para restablecer tu contraseña a $email',
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
              const SimpleHeader(title: 'Privacidad y Seguridad'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    settingsSectionTitle('Seguridad de la cuenta'),
                    SettingsOption(
                      icon: Icons.key_outlined,
                      title: 'Cambiar Contraseña',
                      subtitle: 'Recibirás un correo para restablecerla',
                      onTap: () => _changePassword(context),
                    ),
                    const SettingsOption(
                      icon: Icons.verified_user_outlined,
                      title: 'Estado de la cuenta',
                      subtitle: 'Tu cuenta está protegida por Zentory',
                    ),
                    settingsSectionTitle('Datos personales'),
                    SettingsOption(
                      icon: Icons.delete_forever_outlined,
                      iconColor: AppColors.danger,
                      titleColor: AppColors.danger,
                      title: 'Eliminar mi cuenta',
                      onTap: () => showMessage(
                        context,
                        'Opción no disponible en esta versión',
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
