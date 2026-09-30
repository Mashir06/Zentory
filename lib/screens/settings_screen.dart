import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../services/device_settings.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/notification_setup_sheet.dart';

/// Tarjeta de opción con ícono, título, subtítulo y elemento a la derecha.
class SettingsOption extends StatelessWidget {
  const SettingsOption({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.primary,
    this.titleColor = Colors.white,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              (onTap != null
                  ? const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary)
                  : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

Widget settingsSectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String? _sha1;

  @override
  void initState() {
    super.initState();
    DeviceSettings.signingSha1().then((v) {
      if (mounted) setState(() => _sha1 = v);
    });
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _notifications =
          prefs.getBool(NotificationService.prefNotificationsEnabled) ?? true);
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notifications = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.prefNotificationsEnabled, value);
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      final storeId = await ZentoryRepository.instance.resolveActiveStoreId();
      await NotificationService.instance.syncStore(storeId);
      if (!granted && mounted) await showNotificationSetupSheet(context);
    } else {
      await NotificationService.instance.clearAll();
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (mounted) Routes.resetTo(context, Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                subtitle: 'Configuración',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Ajustes de cuenta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Gestiona tu perfil y preferencias',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SettingsOption(
                      icon: Icons.person_outline,
                      title: 'Editar Perfil y Tienda',
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.profile),
                    ),
                    SettingsOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      subtitle: 'Avisar cuando un producto esté por vencer',
                      onTap: () => _setNotifications(!_notifications),
                      trailing: Switch(
                        value: _notifications,
                        onChanged: _setNotifications,
                      ),
                    ),
                    SettingsOption(
                      icon: Icons.tune,
                      title: 'Configurar notificaciones',
                      subtitle: 'Permisos, batería y prueba de alertas',
                      onTap: () => showNotificationSetupSheet(context),
                    ),
                    SettingsOption(
                      icon: Icons.lock_outline,
                      title: 'Privacidad y Seguridad',
                      onTap: () => Navigator.of(context)
                          .pushNamed(Routes.privacySettings),
                    ),
                    settingsSectionTitle('Ayuda'),
                    SettingsOption(
                      icon: Icons.help_outline,
                      title: 'Ayuda y Soporte',
                      onTap: () => Navigator.of(context).pushNamed(Routes.help),
                    ),
                    const SizedBox(height: 16),
                    SettingsOption(
                      icon: Icons.logout,
                      iconColor: AppColors.danger,
                      titleColor: AppColors.danger,
                      title: 'Cerrar Sesión',
                      trailing: const SizedBox.shrink(),
                      onTap: _logout,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Zentory App v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    // Huella de la firma: se registra en Firebase para que
                    // funcione el inicio de sesión con Google. Toca para copiar.
                    if (_sha1 != null)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _sha1!));
                          showMessage(context, 'Huella SHA-1 copiada');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'SHA-1: $_sha1',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
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
