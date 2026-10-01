import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_settings.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// Muestra la guía para dejar las notificaciones funcionando en el teléfono.
Future<void> showNotificationSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NotificationSetupSheet(),
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
  int _pending = 0;
  bool _autoStartVisited = false;
  bool _alarmClock = false;
  TestScheduleResult? _lastTest;

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
    final pending = await NotificationService.instance.pendingCount();
    final alarmClock = await NotificationService.instance.alarmClockMode();
    if (!mounted) return;
    setState(() {
      _status = status;
      _pending = pending;
      _alarmClock = alarmClock;
    });
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
        'No se pudo abrir la pantalla automáticamente. '
        'Ábrela desde los Ajustes del teléfono.',
        long: true,
      );
    }
  }

  Future<void> _scheduleTest() async {
    await NotificationService.instance.requestPermission();
    final r = await NotificationService.instance.scheduleTestNotification();
    if (!mounted) return;
    setState(() => _lastTest = r);
    if (!r.ok) {
      showMessage(context, r.error!, long: true);
      return;
    }
    showMessage(
      context,
      r.isExact
          ? 'Prueba programada para dentro de 1 minuto. Sal de la app con el '
              'botón de inicio (sin cerrarla desde Recientes) y espera.'
          : 'Prueba programada, pero sin alarmas exactas puede tardar varios '
              'minutos. Activa "Alarmas y recordatorios".',
      long: true,
    );
  }

  Future<void> _setAlarmClock(bool value) async {
    setState(() => _alarmClock = value);
    await NotificationService.instance.setAlarmClockMode(value);
    final storeId = await ZentoryRepository.instance.resolveActiveStoreId();
    await NotificationService.instance.syncStore(storeId);
    _refresh();
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Configurar notificaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s != null && s.hasAggressiveBatteryManager
                ? 'Tu ${s.brand.isEmpty ? 'teléfono' : s.brand} puede cerrar '
                    'Zentory en segundo plano y bloquear las alertas de '
                    'vencimiento. Completa estos pasos para recibirlas.'
                : 'Revisa estos ajustes para recibir las alertas de '
                    'vencimiento aunque la app esté cerrada.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (s == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (s.lastExitForceStopped)
              ZCard(
                color: AppColors.alertBrown,
                margin: const EdgeInsets.only(bottom: 10),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La última vez Zentory se cerró desde Recientes y el '
                        'sistema la detuvo: mientras está así no recibe '
                        'alertas. Fíjala con el candado en Recientes para '
                        'que no vuelva a pasar.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            _StepTile(
              icon: Icons.notifications_active_outlined,
              title: 'Permitir notificaciones',
              description: 'Zentory necesita permiso para mostrar alertas. '
                  'Activa también "Pantalla de bloqueo", "Banners" y el sonido.',
              done: s.notificationsEnabled,
              actionLabel: s.notificationsEnabled ? 'Revisar' : 'Permitir',
              onAction: s.notificationsEnabled
                  ? () => DeviceSettings.openNotificationSettings()
                  : _fixNotifications,
            ),
            _StepTile(
              icon: Icons.alarm_on_outlined,
              title: 'Alarmas y recordatorios',
              description: 'Permite que las alertas lleguen a la hora exacta.',
              done: s.exactAlarmsAllowed,
              actionLabel: 'Permitir',
              onAction: s.exactAlarmsAllowed ? null : _fixExactAlarms,
            ),
            _StepTile(
              icon: Icons.battery_charging_full_outlined,
              title: 'Sin restricciones de batería',
              description: 'Evita que el sistema detenga Zentory para ahorrar '
                  'batería. Elige "Permitir" o "Sin restricciones".',
              done: s.ignoringBatteryOptimizations,
              actionLabel: 'Permitir',
              onAction: s.ignoringBatteryOptimizations ? null : _fixBattery,
            ),
            _StepTile(
              icon: Icons.rocket_launch_outlined,
              title: 'Inicio automático y segundo plano',
              description: s.autoStartHint,
              done: null, // El sistema no permite comprobarlo
              doneLabel: _autoStartVisited ? 'Revisado' : 'Revisar a mano',
              actionLabel: 'Abrir ajustes',
              onAction: _openAutoStart,
            ),
            const _StepTile(
              icon: Icons.lock_outline,
              title: 'No cerrar Zentory desde Recientes',
              description: 'Si deslizas Zentory para cerrarla, el sistema la '
                  'detiene y cancela sus alertas hasta que la vuelvas a abrir. '
                  'Fíjala: abre Recientes, mantén pulsada la tarjeta de '
                  'Zentory (o toca ⋮) y elige "Bloquear" (candado).',
              done: null,
              doneLabel: 'Recomendado',
              actionLabel: '',
              onAction: null,
            ),
            ZCard(
              color: AppColors.background,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.alarm,
                      color: _alarmClock
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modo alarma (más confiable)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Programa los avisos como una alarma de reloj, que '
                          'los teléfonos chinos casi nunca bloquean. Puede '
                          'aparecer un ícono de reloj en la barra de estado.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: _alarmClock, onChanged: _setAlarmClock),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ZCard(
              color: AppColors.background,
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pending == 0
                          ? 'No hay alertas programadas por ahora.'
                          : '$_pending alertas de vencimiento programadas.',
                      style: const TextStyle(color: AppColors.textSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _scheduleTest,
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Probar: enviar aviso en 1 minuto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            if (_lastTest != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _lastTest!.ok
                      ? 'Prueba programada (${_lastTest!.isAlarmClock ? 'modo alarma' : (_lastTest!.isExact ? 'alarma exacta' : 'alarma inexacta')}). '
                          'Si no llega en 1–2 minutos, revisa "Inicio automático '
                          'y segundo plano" y activa el Modo alarma.'
                      : _lastTest!.error!,
                  style: TextStyle(
                    color: _lastTest!.ok
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => DeviceSettings.openAppDetails(),
              child: const Text('Abrir la información de la app'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
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
        doneLabel ?? (done == true ? 'Listo' : 'Pendiente');

    return ZCard(
      color: AppColors.background,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: stateColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    const SizedBox(width: 4),
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
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
