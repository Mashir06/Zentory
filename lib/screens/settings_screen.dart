import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/notification_setup_sheet.dart';
import '../l10n/strings.dart';

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
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
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
                  ? Icon(Icons.chevron_right,
                      color: AppColors.textSecondary)
                  : SizedBox.shrink()),
        ],
      ),
    );
  }
}

Widget settingsSectionTitle(String text) => Padding(
      padding: EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        text,
        style: TextStyle(
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

  /// Versión web: avisos push activados en este navegador.
  bool _webPush = false;
  bool _webPushBusy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _notifications =
          prefs.getBool(NotificationService.prefNotificationsEnabled) ?? true);
    });
    if (kIsWeb) {
      NotificationService.instance.webPushEnabled().then((on) {
        if (mounted) setState(() => _webPush = on);
      });
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
      ));
  }

  /// Versión web: activa o desactiva los avisos push en este navegador.
  /// El permiso se pide en el mismo toque (Safari lo exige).
  Future<void> _setWebPush(bool value) async {
    if (_webPushBusy) return;
    setState(() {
      _webPush = value;
      _webPushBusy = true;
    });
    final service = NotificationService.instance;
    final ok = await service.setWebPushEnabled(value);
    if (!mounted) return;
    setState(() {
      _webPush = value && ok;
      _webPushBusy = false;
    });
    if (value) {
      _toast(ok
          ? tr('Notificaciones activadas en este dispositivo.')
          : (service.lastProblem ??
              tr('No se pudieron activar las notificaciones. Revisa tu conexión e inténtalo de nuevo.')));
    }
  }

  Future<void> _testWebPush() async {
    final service = NotificationService.instance;
    await service.sendTestNotification();
    if (!mounted) return;
    _toast(service.lastProblem ??
        tr('Prueba enviada. Debería llegarte en unos segundos.'));
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

  /// Lista de idiomas; el elegido se aplica al instante en toda la app.
  Future<void> _chooseLanguage() async {
    final chosen = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                tr('Elige el idioma de la aplicación'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final lang in AppLanguage.values)
              ListTile(
                leading: Icon(
                  lang == currentLanguage
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(
                  lang.label,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop(lang),
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await AppSettings.instance.setLanguage(chosen);
    // Las alertas ya programadas se rehacen con los textos del nuevo idioma.
    final storeId = await ZentoryRepository.instance.resolveActiveStoreId();
    await NotificationService.instance.syncStore(storeId);
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
                subtitle: tr('Configuración'),
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text(
                      tr('Ajustes de cuenta'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tr('Gestiona tu perfil y preferencias'),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 12),
                    SettingsOption(
                      icon: Icons.person_outline,
                      title: tr('Editar Perfil y Tienda'),
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.profile),
                    ),
                    if (kIsWeb) ...[
                      SettingsOption(
                        icon: Icons.notifications_outlined,
                        title: tr('Notificaciones'),
                        subtitle: tr('Avisos de vencimiento a las 7:00 a. m. en este dispositivo'),
                        onTap: () => _setWebPush(!_webPush),
                        trailing: Switch(
                          value: _webPush,
                          onChanged: _webPushBusy ? null : _setWebPush,
                        ),
                      ),
                      if (_webPush)
                        SettingsOption(
                          icon: Icons.send_outlined,
                          title: tr('Enviar notificación de prueba'),
                          subtitle: tr('Comprueba que los avisos llegan a este dispositivo'),
                          onTap: _testWebPush,
                        ),
                    ] else ...[
                    SettingsOption(
                      icon: Icons.notifications_outlined,
                      title: tr('Notificaciones'),
                      subtitle: tr('Avisar cuando un producto esté por vencer'),
                      onTap: () => _setNotifications(!_notifications),
                      trailing: Switch(
                        value: _notifications,
                        onChanged: _setNotifications,
                      ),
                    ),
                    SettingsOption(
                      icon: Icons.tune,
                      title: tr('Configurar notificaciones'),
                      subtitle: tr('Permisos, batería y prueba de alertas'),
                      onTap: () => showNotificationSetupSheet(context),
                    ),
                    ],
                    SettingsOption(
                      icon: Icons.lock_outline,
                      title: tr('Privacidad y Seguridad'),
                      onTap: () => Navigator.of(context)
                          .pushNamed(Routes.privacySettings),
                    ),
                    settingsSectionTitle(tr('Suscripción')),
                    SettingsOption(
                      icon: Icons.payments_outlined,
                      title: tr('Estado del pago'),
                      subtitle: tr('Próximo pago, días de gracia e historial'),
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.subscription),
                    ),
                    settingsSectionTitle(tr('Apariencia')),
                    SettingsOption(
                      icon: AppColors.isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      title: tr('Modo oscuro'),
                      subtitle: AppColors.isDark
                          ? tr('Modo oscuro')
                          : tr('Modo claro'),
                      onTap: () =>
                          AppSettings.instance.setDarkMode(!AppColors.isDark),
                      trailing: Switch(
                        value: AppColors.isDark,
                        onChanged: AppSettings.instance.setDarkMode,
                      ),
                    ),
                    SettingsOption(
                      icon: Icons.language,
                      title: tr('Idioma'),
                      subtitle: currentLanguage.label,
                      onTap: _chooseLanguage,
                    ),
                    settingsSectionTitle(tr('Ayuda')),
                    SettingsOption(
                      icon: Icons.help_outline,
                      title: tr('Ayuda y Soporte'),
                      onTap: () => Navigator.of(context).pushNamed(Routes.help),
                    ),
                    SizedBox(height: 16),
                    SettingsOption(
                      icon: Icons.logout,
                      iconColor: AppColors.danger,
                      titleColor: AppColors.danger,
                      title: tr('Cerrar Sesión'),
                      trailing: SizedBox.shrink(),
                      onTap: _logout,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Zentory App v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
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
