import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_settings.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import '../l10n/strings.dart';

/// Muestra la guía para dejar las notificaciones funcionando en el teléfono.
Future<void> showNotificationSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NotificationSetupSheet(),
  );
}

const _prefPrompted = 'notification_setup_prompted_v1';
const _prefForceStopPrompted = 'force_stop_setup_prompted_v1';

/// Abre la guía automáticamente una sola vez si el teléfono tiene algo que
/// impide las alertas (permisos, batería...) o es de un fabricante conocido
/// por bloquear el segundo plano.
Future<void> maybePromptNotificationSetup(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefPrompted) ?? false) {
    // Ya se mostró la guía. Se vuelve a ofrecer (una vez) si detectamos que
    // la app fue cerrada a la fuerza.
    if (prefs.getBool(_prefForceStopPrompted) ?? false) return;
    final status = await DeviceSettings.status();
    if (!status.lastExitForceStopped) return;
    await prefs.setBool(_prefForceStopPrompted, true);
    if (!context.mounted) return;
    await showNotificationSetupSheet(context);
    return;
  }
  if (!(prefs.getBool(NotificationService.prefNotificationsEnabled) ?? true)) {
    return;
  }
  final status = await DeviceSettings.status();
  if (!status.hasBlockingIssue && !status.hasAggressiveBatteryManager) return;
  await prefs.setBool(_prefPrompted, true);
  if (!context.mounted) return;
  await showNotificationSetupSheet(context);
}

class _NotificationSetupSheet extends StatefulWidget {
  const _NotificationSetupSheet();

  @override
  State<_NotificationSetupSheet> createState() =>
      _NotificationSetupSheetState();
}

class _NotificationSetupSheetState extends State<_NotificationSetupSheet>
    with WidgetsBindingObserver {
  DeviceNotificationStatus? _status;
  bool _autoStartVisited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se actualiza el estado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await DeviceSettings.status();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _fixNotifications() async {
    final ok = await NotificationService.instance.requestPermission();
    if (!ok) await DeviceSettings.openNotificationSettings();
    _refresh();
  }

  Future<void> _fixExactAlarms() async {
    await NotificationService.instance.requestExactAlarms();
    final status = await DeviceSettings.status();
    if (!status.exactAlarmsAllowed) {
      await DeviceSettings.openExactAlarmSettings();
    }
    _refresh();
  }

  Future<void> _fixBattery() async {
    await DeviceSettings.requestIgnoreBatteryOptimizations();
    _refresh();
  }

  Future<void> _openAutoStart() async {
    final result = await DeviceSettings.openAutoStartSettings();
    if (!mounted) return;
    setState(() => _autoStartVisited = true);
    if (result == 'none') {
      showMessage(
        context,
        tr('No se pudo abrir la pantalla automáticamente. Ábrela desde los Ajustes del teléfono.'),
        long: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            tr('Configurar notificaciones'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (s == null)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _StepTile(
              icon: Icons.notifications_active_outlined,
              title: tr('Permitir notificaciones'),
              description: tr('Zentory necesita permiso para mostrar alertas. Activa también "Pantalla de bloqueo", "Banners" y el sonido.'),
              done: s.notificationsEnabled,
              actionLabel: s.notificationsEnabled ? tr('Revisar') : tr('Permitir'),
              onAction: s.notificationsEnabled
                  ? () => DeviceSettings.openNotificationSettings()
                  : _fixNotifications,
            ),
            _StepTile(
              icon: Icons.alarm_on_outlined,
              title: tr('Alarmas y recordatorios'),
              description: tr('Permite que las alertas lleguen a la hora exacta.'),
              done: s.exactAlarmsAllowed,
              actionLabel: tr('Permitir'),
              onAction: s.exactAlarmsAllowed ? null : _fixExactAlarms,
            ),
            _StepTile(
              icon: Icons.battery_charging_full_outlined,
              title: tr('Sin restricciones de batería'),
              description: tr('Evita que el sistema detenga Zentory para ahorrar batería. Se abrirá la información de la app: entra en "Batería" y elige "Sin restricciones".'),
              done: s.ignoringBatteryOptimizations,
              actionLabel: tr('Abrir ajustes'),
              onAction: s.ignoringBatteryOptimizations ? null : _fixBattery,
            ),
            _StepTile(
              icon: Icons.rocket_launch_outlined,
              title: tr('Inicio automático y segundo plano'),
              description: s.autoStartHint,
              done: null, // El sistema no permite comprobarlo
              doneLabel: _autoStartVisited ? tr('Revisado') : tr('Revisar a mano'),
              actionLabel: tr('Abrir ajustes'),
              onAction: _openAutoStart,
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => DeviceSettings.openAppDetails(),
              child: Text(tr('Abrir la información de la app')),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Listo')),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.actionLabel,
    required this.onAction,
    this.doneLabel,
  });

  final IconData icon;
  final String title;
  final String description;

  /// `true` listo, `false` falta, `null` no se puede comprobar.
  final bool? done;
  final String? doneLabel;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final Color stateColor = done == null
        ? AppColors.warning
        : (done! ? AppColors.primary : AppColors.danger);
    final String stateText =
        doneLabel ?? (done == true ? tr('Listo') : tr('Pendiente'));

    return ZCard(
      color: AppColors.background,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: stateColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done == true
                          ? Icons.check_circle
                          : (done == false
                              ? Icons.error_outline
                              : Icons.help_outline),
                      size: 14,
                      color: stateColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      stateText,
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            )
          else
            SizedBox(height: 6),
        ],
      ),
    );
  }
}
