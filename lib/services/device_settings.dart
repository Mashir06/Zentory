import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../l10n/strings.dart';

/// Estado de los ajustes del teléfono que afectan a las notificaciones
/// programadas.
class DeviceNotificationStatus {
  const DeviceNotificationStatus({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.sdkInt,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.ignoringBatteryOptimizations,
    this.lastExitForceStopped = false,
  });

  final String manufacturer;
  final String brand;
  final String model;
  final int sdkInt;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool ignoringBatteryOptimizations;

  /// La última vez que se cerró, Zentory fue "detenida a la fuerza" (p. ej.
  /// al deslizarla en Recientes): Android canceló sus alarmas.
  final bool lastExitForceStopped;

  /// Valores por defecto si no se pudo consultar (p. ej. en pruebas).
  static const unknown = DeviceNotificationStatus(
    manufacturer: '',
    brand: '',
    model: '',
    sdkInt: 0,
    notificationsEnabled: true,
    exactAlarmsAllowed: true,
    ignoringBatteryOptimizations: true,
  );

  String get _maker => '${manufacturer.toLowerCase()} ${brand.toLowerCase()}';

  bool get isOppoFamily =>
      _maker.contains('oppo') ||
      _maker.contains('realme') ||
      _maker.contains('oneplus') ||
      _maker.contains('oplus');

  bool get isXiaomiFamily =>
      _maker.contains('xiaomi') ||
      _maker.contains('redmi') ||
      _maker.contains('poco');

  bool get isVivoFamily => _maker.contains('vivo') || _maker.contains('iqoo');

  bool get isHuaweiFamily =>
      _maker.contains('huawei') || _maker.contains('honor');

  /// Fabricantes conocidos por cerrar apps en segundo plano y borrar sus
  /// alarmas (sobre todo en las versiones para China).
  bool get hasAggressiveBatteryManager =>
      isOppoFamily ||
      isXiaomiFamily ||
      isVivoFamily ||
      isHuaweiFamily ||
      _maker.contains('meizu') ||
      _maker.contains('samsung') ||
      _maker.contains('asus') ||
      _maker.contains('lenovo') ||
      _maker.contains('zte') ||
      _maker.contains('nubia') ||
      _maker.contains('tecno') ||
      _maker.contains('infinix');

  /// Hay algo que seguro impide o retrasa las alertas.
  bool get hasBlockingIssue =>
      !notificationsEnabled ||
      !exactAlarmsAllowed ||
      !ignoringBatteryOptimizations;

  /// Instrucciones para permitir el inicio automático / segundo plano.
  String get autoStartHint {
    if (isOppoFamily) {
      return tr('Ajustes > Apps > Gestión de apps > Zentory > Uso de batería: activa "Permitir actividad en segundo plano" y "Permitir inicio automático". También puedes fijar Zentory en Recientes (mantén pulsada la tarjeta y toca el candado).');
    }
    if (isXiaomiFamily) {
      return tr('Ajustes > Apps > Administrar apps > Zentory: activa "Inicio automático" y en "Ahorro de batería" elige "Sin restricciones".');
    }
    if (isVivoFamily) {
      return tr('Ajustes > Batería > Consumo en segundo plano: permite Zentory. En i Manager > Administrador de apps > Inicio automático, actívalo.');
    }
    if (isHuaweiFamily) {
      return tr('Ajustes > Batería > Inicio de apps > Zentory: desactiva "Gestionar automáticamente" y activa las tres opciones.');
    }
    return tr('En los ajustes de la app, permite el inicio automático y la actividad en segundo plano, y quita cualquier restricción de batería.');
  }
}

/// Acceso a los ajustes del teléfono mediante el canal nativo de MainActivity.
class DeviceSettings {
  DeviceSettings._();

  static const _channel = MethodChannel('zentory/device');

  static Future<DeviceNotificationStatus> status() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (map == null) return DeviceNotificationStatus.unknown;
      return DeviceNotificationStatus(
        manufacturer: (map['manufacturer'] ?? '') as String,
        brand: (map['brand'] ?? '') as String,
        model: (map['model'] ?? '') as String,
        sdkInt: (map['sdkInt'] ?? 0) as int,
        notificationsEnabled: (map['notificationsEnabled'] ?? true) as bool,
        exactAlarmsAllowed: (map['exactAlarmsAllowed'] ?? true) as bool,
        ignoringBatteryOptimizations:
            (map['ignoringBatteryOptimizations'] ?? true) as bool,
        lastExitForceStopped: (map['lastExitForceStopped'] ?? false) as bool,
      );
    } catch (e) {
      debugPrint('No se pudo leer el estado del dispositivo: $e');
      return DeviceNotificationStatus.unknown;
    }
  }

  static Future<bool> _call(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      debugPrint('Error al abrir ajustes ($method): $e');
      return false;
    }
  }

  static Future<bool> openNotificationSettings() =>
      _call('openNotificationSettings');

  static Future<bool> openExactAlarmSettings() =>
      _call('openExactAlarmSettings');

  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _call('requestIgnoreBatteryOptimizations');

  static Future<bool> openAppDetails() => _call('openAppDetails');

  // --- Limpieza del antiguo respaldo en calendario ------------------------

  static Future<bool> hasCalendarPermission() => _call('hasCalendarPermission');

  /// Borra el calendario "Zentory - Vencimientos" que creaban las versiones
  /// anteriores de la app.
  static Future<void> removeCalendar() async {
    try {
      await _channel.invokeMethod<bool>('removeCalendar');
    } catch (e) {
      debugPrint('No se pudo borrar el calendario: $e');
    }
  }

  /// Huella SHA-1 con la que está firmada la app (para registrarla en
  /// Firebase y habilitar el inicio de sesión con Google).
  static Future<String?> signingSha1() async {
    try {
      return await _channel.invokeMethod<String>('getSigningSha1');
    } catch (_) {
      return null;
    }
  }

  /// `true` si el teléfono tiene los servicios de Google Play (necesarios para
  /// iniciar sesión con Google). Si no se puede comprobar, asume que sí.
  static Future<bool> hasGooglePlayServices() async {
    try {
      return await _channel.invokeMethod<bool>('hasGooglePlayServices') ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Devuelve "oem", "app_details" o "none".
  static Future<String> openAutoStartSettings() async {
    try {
      return await _channel.invokeMethod<String>('openAutoStartSettings') ??
          'none';
    } catch (e) {
      debugPrint('Error al abrir inicio automático: $e');
      return 'none';
    }
  }
}
