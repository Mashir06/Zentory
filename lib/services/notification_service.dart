import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/product.dart';
import '../utils/image_utils.dart';
import 'device_settings.dart';
import 'zentory_repository.dart';
import '../l10n/strings.dart';

/// Alertas locales de vencimiento de productos.
///
/// Diseño pensado para teléfonos con ROM china (ColorOS, MIUI/HyperOS,
/// OriginOS, EMUI...), que cierran las apps en segundo plano y **borran sus
/// alarmas programadas**:
///
/// * Las alertas no se programan "sueltas": cada vez que se abre la app, o se
///   guarda o elimina un producto, se **resincronizan** todas las alertas de la
///   tienda a partir de Firestore. Si el sistema las borró, se recrean.
/// * Cada lote (registro) tiene sus propias alertas, identificadas por el ID del
///   documento: dos lotes con el mismo nombre ya no se pisan entre sí.
/// * Se usan alarmas exactas cuando el sistema lo permite, y si no, alarmas
///   inexactas que igualmente se disparan con el teléfono en reposo.
/// * El canal se crea con importancia alta desde el inicio y el ícono pequeño
///   es monocromo (algunas ROM descartan notificaciones con íconos a color).
/// * Los permisos y ajustes del fabricante se revisan en
///   `NotificationSetupSheet` (Ajustes > Configurar notificaciones).
///
/// Por cada lote se avisa a las 7:00 a. m.: 3 días antes, 1 día antes y el día
/// del vencimiento.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String prefNotificationsEnabled = 'notifications_enabled';

  /// Usar alarmas "de reloj" (como el despertador). Son las que los sistemas
  /// con ahorro de batería agresivo (ColorOS, MIUI...) casi nunca bloquean.
  /// Si el usuario no lo eligió, se activa sola en esos fabricantes.
  static const String prefAlarmClockMode = 'alarm_clock_mode';

  static const _channelId = 'expiration_notifications_custom_sound';
  static const _channelName = 'Vencimientos de Productos';
  static const _channelDescription =
      'Avisos antes de que venzan los productos del inventario';
  static const _title = 'Alerta de Vencimiento';

  /// IDs reservados para las pruebas (no se tocan al resincronizar).
  static const _testNowId = 999;
  static const _testScheduledId = 998;

  /// Hora del aviso.
  static const _alertHour = 7;

  /// Android limita cuántas alarmas puede tener una app; se programan solo
  /// las más próximas (el resto se programa en siguientes resincronizaciones).
  static const _maxScheduled = 150;


  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initFuture;

  /// Evita resincronizaciones simultáneas.
  Future<void> _syncChain = Future.value();

  /// Firma de la última programación hecha en este proceso. Si la app se
  /// reinicia (o el sistema la cerró) es `null` y se vuelve a programar todo.
  String? _lastSignature;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('logozentory'),
      color: Color(0xFF10B981),
      ticker: 'Alerta de vencimiento',
      autoCancel: true,
      channelShowBadge: true,
    ),
  );

  // ---------------------------------------------------------------------------
  // Inicialización y permisos
  // ---------------------------------------------------------------------------

  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _plugin.initialize(settings);
      // Crear el canal desde el inicio con importancia alta: algunas ROM
      // crean los canales "silenciosos" si nacen al mostrar la primera
      // notificación, y así el usuario ya puede verlo en los ajustes.
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          enableVibration: true,
          showBadge: true,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('No se pudieron iniciar las notificaciones: $e');
      _initFuture = null; // permitir reintentar
    }
  }

  /// Pide el permiso de notificaciones (Android 13+). Devuelve `false` si
  /// siguen desactivadas.
  Future<bool> requestPermission() async {
    await init();
    final android = _android;
    if (android == null) return true;
    try {
      await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? true;
    } catch (e) {
      debugPrint('Error al pedir permiso de notificaciones: $e');
      return false;
    }
  }

  /// Abre la pantalla del sistema para permitir alarmas exactas.
  Future<void> requestExactAlarms() async {
    await init();
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Error al pedir alarmas exactas: $e');
    }
  }

  Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefNotificationsEnabled) ?? true;
  }

  /// `true` si está activo el modo alarma de reloj.
  Future<bool> alarmClockMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(prefAlarmClockMode);
    if (saved != null) return saved;
    final status = await DeviceSettings.status();
    return status.hasAggressiveBatteryManager;
  }

  Future<void> setAlarmClockMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefAlarmClockMode, value);
    _lastSignature = null; // obliga a reprogramar con el modo nuevo
  }

  /// Alarma de reloj > exacta > inexacta, según lo que permita el teléfono.
  Future<AndroidScheduleMode> _scheduleMode() async {
    bool exact;
    try {
      exact = await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      exact = false;
    }
    if (!exact) return AndroidScheduleMode.inexactAllowWhileIdle;
    return await alarmClockMode()
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;
  }

  // ---------------------------------------------------------------------------
  // Resincronización de alertas
  // ---------------------------------------------------------------------------

  /// Vuelve a leer los productos de la tienda y reprograma sus alertas.
  Future<void> syncStore(String? storeId) async {
    if (storeId == null) return cancelExpiryAlerts();
    try {
      final products = await ZentoryRepository.instance.fetchProducts(storeId);
      await syncProducts(products);
    } catch (e) {
      debugPrint('No se pudieron sincronizar las alertas: $e');
    }
  }

  /// Reprograma las alertas de la lista de productos (lotes) indicada.
  Future<void> syncProducts(List<Product> products, {bool force = false}) {
    final next = _syncChain.then((_) => _sync(products, force: force));
    _syncChain = next.catchError((Object e) {
      debugPrint('Error al sincronizar alertas: $e');
    });
    return _syncChain;
  }

  Future<void> _sync(List<Product> products, {required bool force}) async {
    await init();
    if (!_initialized) return;

    if (!await _enabled()) {
      await cancelExpiryAlerts();
      return;
    }

    final alerts = _buildAlerts(products);
    final mode = await _scheduleMode();
    final ids =
        alerts.map((a) => '${a.id}@${a.when.millisecondsSinceEpoch}').join(',');
    final signature = '${mode.name}|${currentLanguage.code}|$ids';
    if (!force && signature == _lastSignature) return;

    await cancelExpiryAlerts();
    for (final a in alerts) {
      try {
        await _plugin.zonedSchedule(
          a.id,
          tr(_title),
          a.body,
          // El instante local se pasa a UTC; Android lo programa por tiempo
          // absoluto, así que la hora local se respeta.
          tz.TZDateTime.from(a.when, tz.UTC),
          _details,
          androidScheduleMode: mode,
          payload: a.productId,
        );
      } catch (e) {
        debugPrint('No se pudo programar la alerta ${a.id}: $e');
      }
    }
    _lastSignature = signature;
  }

  List<_Alert> _buildAlerts(List<Product> products) {
    final now = DateTime.now();
    final alerts = <_Alert>[];
    for (final p in products) {
      final expiry = p.expiryDate;
      if (expiry == null) continue;
      final name = p.nombre.trim().isEmpty ? 'Producto' : p.nombre.trim();
      void add(int daysBefore, String suffix, String message) {
        final when = DateTime(
          expiry.year,
          expiry.month,
          expiry.day - daysBefore,
          _alertHour,
        );
        if (!when.isAfter(now)) return;
        alerts.add(_Alert(
          id: javaStringHash('${p.id}_$suffix'),
          productId: p.id,
          when: when,
          body: '$name: $message',
        ));
      }

      add(3, '3', tr('Está cerca de vencer (3 días)'));
      add(1, '1', tr('Vence mañana'));
      add(0, '0', tr('Vence hoy'));
    }
    alerts.sort((a, b) => a.when.compareTo(b.when));
    return alerts.length > _maxScheduled
        ? alerts.sublist(0, _maxScheduled)
        : alerts;
  }

  /// Borra todas las alertas locales (p. ej. al cerrar sesión).
  Future<void> clearAll() => cancelExpiryAlerts();

  /// Cancela todas las alertas de vencimiento programadas (no las pruebas).
  Future<void> cancelExpiryAlerts() async {
    await init();
    if (!_initialized) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final r in pending) {
        if (r.id == _testNowId || r.id == _testScheduledId) continue;
        await _plugin.cancel(r.id);
      }
    } catch (e) {
      debugPrint('No se pudieron cancelar las alertas: $e');
    }
    _lastSignature = null;
  }

  /// Cantidad de alertas de vencimiento pendientes.
  Future<int> pendingCount() async {
    await init();
    if (!_initialized) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending
          .where((r) => r.id != _testNowId && r.id != _testScheduledId)
          .length;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Pruebas
  // ---------------------------------------------------------------------------

  /// Muestra una notificación inmediata.
  Future<void> sendTestNotification() async {
    await init();
    if (!_initialized) return;
    await _plugin.show(
      _testNowId,
      tr(_title),
      tr('Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉'),
      _details,
    );
  }

  /// Programa una notificación de prueba dentro de [delay]. Sirve para
  /// comprobar que las alertas llegan con la app cerrada (que es justo lo que
  /// bloquean las ROM chinas).
  Future<TestScheduleResult> scheduleTestNotification({
    Duration delay = const Duration(minutes: 1),
  }) async {
    await init();
    if (!_initialized) {
      return const TestScheduleResult.error(
          'No se pudieron iniciar las notificaciones.');
    }
    final mode = await _scheduleMode();
    try {
      await _plugin.cancel(_testScheduledId);
      await _plugin.zonedSchedule(
        _testScheduledId,
        tr(_title),
        tr('Prueba programada de Zentory: si ves esto con la app cerrada, las alertas de vencimiento te llegarán. ✅'),
        tz.TZDateTime.from(DateTime.now().add(delay), tz.UTC),
        _details,
        androidScheduleMode: mode,
      );
      final pending = await _plugin.pendingNotificationRequests();
      if (!pending.any((r) => r.id == _testScheduledId)) {
        return const TestScheduleResult.error(
            'El sistema no aceptó la alarma de prueba.');
      }
      return TestScheduleResult.ok(mode);
    } catch (e) {
      debugPrint('No se pudo programar la prueba: $e');
      return TestScheduleResult.error('No se pudo programar la prueba: $e');
    }
  }
}

/// Resultado de programar la notificación de prueba.
class TestScheduleResult {
  const TestScheduleResult.ok(AndroidScheduleMode this.mode) : error = null;
  const TestScheduleResult.error(String this.error) : mode = null;

  final AndroidScheduleMode? mode;
  final String? error;

  bool get ok => error == null;
  bool get isAlarmClock => mode == AndroidScheduleMode.alarmClock;
  bool get isExact =>
      mode == AndroidScheduleMode.alarmClock ||
      mode == AndroidScheduleMode.exactAllowWhileIdle;
}

class _Alert {
  _Alert({
    required this.id,
    required this.productId,
    required this.when,
    required this.body,
  });

  final int id;
  final String productId;
  final DateTime when;
  final String body;
}
