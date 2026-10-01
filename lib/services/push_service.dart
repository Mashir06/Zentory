import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_settings.dart';
import 'notification_service.dart';
import 'zentory_repository.dart';

/// Estado de las notificaciones push en este teléfono.
class PushStatus {
  const PushStatus({
    required this.googleServices,
    required this.hasToken,
    required this.serverLastRun,
    this.error,
  });

  /// El teléfono tiene los servicios de Google Play activos.
  final bool googleServices;

  /// Se obtuvo el identificador FCM de este teléfono.
  final bool hasToken;

  /// Última vez que el servidor (Cloud Function diaria) revisó la tienda.
  final DateTime? serverLastRun;

  final String? error;

  bool get serverActive =>
      serverLastRun != null &&
      DateTime.now().difference(serverLastRun!) < PushService.serverFreshness;

  /// El push cubre las alertas: servidor activo y teléfono registrado.
  bool get working => googleServices && hasToken && serverActive;
}

/// Notificaciones push con Firebase Cloud Messaging (FCM).
///
/// El servidor (`functions/index.js`) revisa cada mañana los lotes de cada
/// tienda y envía los avisos a **todos** los teléfonos registrados en ella
/// (`tiendas/{tiendaId}/dispositivos/{token}`), así que también le llegan al
/// personal que no registró el lote.
///
/// Si el teléfono no tiene servicios de Google o el servidor no está activo,
/// la app sigue usando las alarmas locales de [NotificationService] como
/// respaldo; cuando el push funciona, las alarmas locales se apagan para no
/// recibir avisos dobles.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Si el servidor no ha revisado la tienda en este tiempo, se considera
  /// inactivo y se vuelve a las alarmas locales.
  static const serverFreshness = Duration(hours: 36);

  static const _prefRegisteredStore = 'push_registered_store';

  final _repo = ZentoryRepository.instance;

  String? _token;
  String? _lastError;
  bool _initialized = false;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  String? get token => _token;

  /// Prepara FCM. No bloquea si el teléfono no tiene servicios de Google.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!await DeviceSettings.hasGooglePlayServices()) {
      _lastError = 'Servicios de Google Play desactivados';
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      _token = await messaging.getToken().timeout(const Duration(seconds: 20));
      _lastError = null;

      _tokenSub = messaging.onTokenRefresh.listen((t) async {
        _token = t;
        final prefs = await SharedPreferences.getInstance();
        final storeId = prefs.getString(_prefRegisteredStore);
        if (storeId != null) await _saveToken(storeId, t);
      });

      // Con la app abierta, FCM no muestra la notificación: la mostramos
      // nosotros con el mismo canal y sonido que las alertas locales.
      _messageSub = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        NotificationService.instance.showRemote(
          title: n.title ?? 'Alerta de Vencimiento',
          body: n.body ?? '',
          tag: m.data['tipo'] as String?,
        );
      });
    } catch (e) {
      _lastError = 'No se pudo obtener el identificador push: $e';
      debugPrint(_lastError);
      _initialized = false; // reintentar en la próxima llamada
    }
  }

  /// Vuelve a intentar obtener el token (p. ej. después de que el usuario
  /// activó los servicios de Google).
  Future<void> retry() async {
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
    _initialized = false;
    await init();
  }

  Future<void> _saveToken(String storeId, String token) {
    return _repo.stores.doc(storeId).collection('dispositivos').doc(token).set({
      'uid': _repo.currentUser?.uid,
      'plataforma': defaultTargetPlatform.name,
      'actualizado': FieldValue.serverTimestamp(),
    });
  }

  /// Registra este teléfono en la tienda activa para recibir sus avisos. Si
  /// antes estaba registrado en otra tienda, lo quita de esa.
  Future<void> registerForStore(String? storeId) async {
    await init();
    final token = _token;
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_prefRegisteredStore);
    try {
      if (previous != null && previous != storeId) {
        await _repo.stores
            .doc(previous)
            .collection('dispositivos')
            .doc(token)
            .delete();
      }
      if (storeId == null) {
        await prefs.remove(_prefRegisteredStore);
        return;
      }
      await _saveToken(storeId, token);
      await prefs.setString(_prefRegisteredStore, storeId);
    } catch (e) {
      _lastError = 'No se pudo registrar el teléfono en la tienda: $e';
      debugPrint(_lastError);
    }
  }

  /// Quita este teléfono de la tienda (al cerrar sesión).
  Future<void> unregister() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString(_prefRegisteredStore);
    final token = _token;
    try {
      if (storeId != null && token != null) {
        await _repo.stores
            .doc(storeId)
            .collection('dispositivos')
            .doc(token)
            .delete();
      }
    } catch (e) {
      debugPrint('No se pudo quitar el teléfono de la tienda: $e');
    }
    await prefs.remove(_prefRegisteredStore);
  }

  /// Última vez que el servidor revisó la tienda.
  Future<DateTime?> serverLastRun(String storeId) async {
    try {
      final doc = await _repo.stores.doc(storeId).get();
      final info = doc.data()?['pushServidor'];
      if (info is Map && info['ultimaEjecucion'] is Timestamp) {
        return (info['ultimaEjecucion'] as Timestamp).toDate();
      }
    } catch (_) {}
    return null;
  }

  /// `true` si el push cubre las alertas de esta tienda en este teléfono.
  Future<bool> coversStore(String storeId) async {
    await init();
    if (_token == null) return false;
    final last = await serverLastRun(storeId);
    return last != null && DateTime.now().difference(last) < serverFreshness;
  }

  Future<PushStatus> status(String? storeId) async {
    await init();
    return PushStatus(
      googleServices: await DeviceSettings.hasGooglePlayServices(),
      hasToken: _token != null,
      serverLastRun: storeId == null ? null : await serverLastRun(storeId),
      error: _lastError,
    );
  }

  /// Pide al servidor que envíe una notificación push de prueba a este
  /// teléfono. Devuelve un mensaje de error, o `null` si se solicitó bien.
  Future<String?> sendTest(String storeId) async {
    await init();
    final token = _token;
    if (token == null) {
      return _lastError ??
          'Este teléfono no tiene identificador push. Activa los servicios '
              'de Google Play.';
    }
    try {
      await _repo.stores.doc(storeId).collection('pruebasPush').add({
        'token': token,
        'uid': _repo.currentUser?.uid,
        'creado': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo solicitar la prueba: $e';
    }
  }
}
