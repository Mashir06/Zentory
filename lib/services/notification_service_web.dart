import '../models/product.dart';

/// Versión web de [NotificationService]: el navegador no permite programar
/// alertas locales a una hora fija, así que todas las operaciones son
/// "no hacer nada". Las alertas de vencimiento llegan en la app de Android.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String prefNotificationsEnabled = 'notifications_enabled';
  static const String prefAlarmClockMode = 'alarm_clock_mode';

  /// `false`: en la web no hay alertas programadas.
  static const bool supported = false;

  Future<void> init() async {}

  Future<bool> requestPermission() async => false;

  Future<void> requestExactAlarms() async {}

  Future<bool> alarmClockMode() async => false;

  Future<void> setAlarmClockMode(bool value) async {}

  Future<void> syncStore(String? storeId) async {}

  Future<void> syncProducts(List<Product> products, {bool force = false}) async {}

  Future<void> clearAll() async {}

  Future<void> cancelExpiryAlerts() async {}

  Future<int> pendingCount() async => 0;

  Future<void> sendTestNotification() async {}
}
