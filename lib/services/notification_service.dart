import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/date_utils.dart';
import '../utils/image_utils.dart';

/// Alertas de vencimiento (reemplaza NotificationHelper + NotificationReceiver
/// de la app Kotlin).
///
/// Por cada producto se programan dos avisos a las 9:00 a. m.:
/// 3 días antes y 1 día antes de la fecha de vencimiento.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String prefNotificationsEnabled = 'notifications_enabled';

  static const _channelId = 'expiration_notifications_custom_sound';
  static const _channelName = 'Vencimientos de Productos';
  static const _channelDescription = 'Notificaciones con sonido personalizado';
  static const _title = 'Alerta de Vencimiento';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      icon: 'logozentory',
      autoCancel: true,
    ),
  );

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('logozentory'),
    );
    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('No se pudieron iniciar las notificaciones: $e');
    }
  }

  /// Pide el permiso de notificaciones (Android 13+). Devuelve `false` si el
  /// usuario lo rechazó.
  Future<bool> requestPermission() async {
    await init();
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefNotificationsEnabled) ?? true;
  }

  static int _idFor(String productName, String suffix) =>
      javaStringHash(productName + suffix);

  Future<void> scheduleProductNotifications(
    String productName,
    String expiryDateStr,
  ) async {
    await init();
    if (!_initialized || !await _enabled()) return;
    final expiry = DateUtilsZ.parse(expiryDateStr);
    if (expiry == null) return;

    // Reprogramar desde cero si el producto ya tenía avisos
    await cancelProductNotifications(productName);

    final threeDaysBefore =
        DateTime(expiry.year, expiry.month, expiry.day - 3, 9);
    final oneDayBefore = DateTime(expiry.year, expiry.month, expiry.day - 1, 9);

    await _schedule(
      _idFor(productName, '3'),
      productName,
      'Está cerca de vencer (3 días)',
      threeDaysBefore,
    );
    await _schedule(
      _idFor(productName, '1'),
      productName,
      'Vence mañana',
      oneDayBefore,
    );
  }

  Future<void> _schedule(
    int id,
    String productName,
    String message,
    DateTime when,
  ) async {
    if (!when.isAfter(DateTime.now())) return;
    final canExact =
        await _android?.canScheduleExactNotifications() ?? false;
    try {
      await _plugin.zonedSchedule(
        id,
        _title,
        '$productName: $message',
        // Se convierte el instante local a UTC; Android lo programa por
        // tiempo absoluto, así que la hora local se respeta.
        tz.TZDateTime.from(when, tz.UTC),
        _details,
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('No se pudo programar la notificación: $e');
    }
  }

  Future<void> cancelProductNotifications(String productName) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(_idFor(productName, '3'));
    await _plugin.cancel(_idFor(productName, '1'));
  }

  Future<void> sendTestNotification() async {
    await init();
    if (!_initialized) return;
    await _plugin.show(
      999,
      _title,
      'Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉',
      _details,
    );
  }
}
