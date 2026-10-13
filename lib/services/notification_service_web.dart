import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../l10n/strings.dart';
import '../models/product.dart';

/// Versión web de [NotificationService]: avisos de vencimiento por
/// notificaciones push (Firebase Cloud Messaging).
///
/// El navegador no puede programar alertas locales a una hora fija, así que
/// las manda el servidor: la función `avisosVencimientoWeb` (carpeta
/// `functions/`) corre todos los días a las 7:00 a. m. (hora de Panamá) y
/// avisa 3 días antes, 1 día antes y el día del vencimiento, igual que la app
/// de Android.
///
/// Cómo funciona en el navegador:
/// * El usuario las activa en Ajustes > Notificaciones (el permiso solo se
///   puede pedir cuando la persona toca algo).
/// * Se guarda el identificador de este navegador en
///   `usuarios/{uid}.avisosWeb.{token}` = { idioma, actualizado } y
///   `usuarios/{uid}.avisosWebActivos` = true. El servidor avisa de la tienda
///   activa del usuario (`usuarios/{uid}.tiendaId`).
/// * Con la app cerrada, los avisos los muestra el archivo
///   `firebase-messaging-sw.js`, que va en la raíz de nubiksoft.com.
/// * En iPhone solo funciona con iOS 16.4 o más nuevo y con Zentory agregada a
///   la pantalla de inicio.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String prefNotificationsEnabled = 'notifications_enabled';
  static const String prefAlarmClockMode = 'alarm_clock_mode';

  /// Preferencia propia de la web: empieza apagada porque el navegador solo
  /// deja pedir el permiso cuando el usuario lo activa.
  static const String prefWebPushEnabled = 'web_push_enabled';
  static const String _prefWebPushToken = 'web_push_token';

  /// `true`: en la web los avisos llegan por notificaciones push.
  static const bool supported = true;

  /// Llave pública para Web Push (Firebase > Configuración del proyecto >
  /// Cloud Messaging > Certificados push web). Con `null` se usa la llave
  /// predeterminada de Firebase, que funciona igual.
  static const String? _vapidKey = null;

  /// Función que manda una notificación de prueba a los dispositivos del
  /// usuario (ver `functions/index.js`).
  static const String _testUrl =
      'https://us-central1-zentory-base.cloudfunctions.net/probarAvisoWeb';

  static const String _iosHint =
      'En iPhone, primero agrega Zentory a la pantalla de inicio (Compartir → Agregar a inicio) y ábrela desde ahí para activar las notificaciones.';
  static const String _noBrowser = 'Este navegador no permite notificaciones.';
  static const String _failed =
      'No se pudieron activar las notificaciones. Revisa tu conexión e inténtalo de nuevo.';

  /// Motivo del último intento fallido, para mostrarlo en pantalla.
  String? lastProblem;

  bool _listening = false;

  /// Último registro guardado en Firestore (`uid|token|idioma`), para no
  /// escribir lo mismo cada vez que se abre la app.
  String? _savedSignature;

  // ---------------------------------------------------------------------------
  // Compatibilidad del navegador
  // ---------------------------------------------------------------------------

  bool get _browserHasPush =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      web.window.navigator.has('serviceWorker');

  bool get _isApple {
    final ua = web.window.navigator.userAgent;
    return ua.contains('iPhone') ||
        ua.contains('iPad') ||
        (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
  }

  String get _permission => globalContext.has('Notification')
      ? web.Notification.permission
      : 'denied';

  // ---------------------------------------------------------------------------
  // Interfaz común con la versión de Android
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_listening || !_browserHasPush) return;
    _listening = true;
    try {
      // Con la app abierta el navegador no muestra el aviso por su cuenta:
      // se muestra aquí.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        _showLocal(n?.title ?? tr('Alerta de Vencimiento'), n?.body ?? '');
      });
    } catch (e) {
      debugPrint('Avisos web no disponibles: $e');
    }
  }

  /// Pide el permiso del navegador y registra este dispositivo. Debe llamarse
  /// al tocar un botón (los navegadores, sobre todo Safari, lo exigen).
  Future<bool> requestPermission() async {
    lastProblem = null;
    if (!_browserHasPush) {
      lastProblem = tr(_isApple ? _iosHint : _noBrowser);
      return false;
    }
    try {
      // Primero el permiso, sin esperar nada antes: Safari solo lo acepta
      // justo después de que el usuario toca la pantalla.
      final settings = await FirebaseMessaging.instance.requestPermission();
      final status = settings.authorizationStatus;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        lastProblem = status == AuthorizationStatus.denied
            ? tr('Las notificaciones están bloqueadas para este sitio. Actívalas en los ajustes del navegador.')
            : tr('No se activaron las notificaciones.');
        return false;
      }
      if (!await FirebaseMessaging.instance.isSupported()) {
        lastProblem = tr(_isApple ? _iosHint : _noBrowser);
        return false;
      }
      return await _register(force: true);
    } catch (e) {
      debugPrint('No se pudo pedir el permiso de notificaciones: $e');
      lastProblem = tr(_failed);
      return false;
    }
  }

  /// `true` si el usuario activó los avisos en este navegador y el permiso
  /// sigue dado.
  Future<bool> webPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(prefWebPushEnabled) ?? false) &&
        _permission == 'granted';
  }

  /// Activa o desactiva los avisos en este navegador. Devuelve `false` si no
  /// se pudieron activar (el motivo queda en [lastProblem]).
  Future<bool> setWebPushEnabled(bool value) async {
    if (!value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefWebPushEnabled, false);
      await _unregister();
      return true;
    }
    // El permiso se pide antes de cualquier otra espera (ver arriba).
    final ok = await requestPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefWebPushEnabled, ok);
    return ok;
  }

  Future<void> requestExactAlarms() async {}

  Future<bool> alarmClockMode() async => false;

  Future<void> setAlarmClockMode(bool value) async {}

  /// En la web no se programa nada en el dispositivo: solo se confirma que
  /// este navegador sigue registrado (su identificador puede cambiar) y con
  /// el idioma actual.
  Future<void> syncStore(String? storeId) => _refresh();

  Future<void> syncProducts(List<Product> products, {bool force = false}) =>
      _refresh();

  /// Al cerrar sesión: este navegador deja de recibir los avisos de la cuenta.
  Future<void> clearAll() => _unregister();

  Future<void> cancelExpiryAlerts() async {}

  Future<int> pendingCount() async => 0;

  /// Pide al servidor una notificación de prueba para los dispositivos del
  /// usuario. Si el servidor todavía no está activo, muestra una prueba solo
  /// en este dispositivo y lo explica en [lastProblem].
  Future<void> sendTestNotification() async {
    lastProblem = null;
    try {
      if (!await _register(force: true)) throw StateError('sin registro');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) throw StateError('sin sesión');
      final res = await http
          .post(
            Uri.parse(_testUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'idioma': currentLanguage.code}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw StateError('HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Prueba por el servidor no disponible: $e');
      lastProblem = tr('El servidor de avisos todavía no está activo. Se mostró una prueba solo en este dispositivo.');
      _showLocal(
        tr('Alerta de Vencimiento'),
        tr('Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Registro del dispositivo en Firestore
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    try {
      if (!await webPushEnabled()) return;
      await _register();
    } catch (e) {
      debugPrint('No se pudo actualizar el registro de avisos: $e');
    }
  }

  Future<bool> _register({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      lastProblem = tr(_failed);
      return false;
    }
    final token =
        await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey);
    if (token == null || token.isEmpty) {
      lastProblem = tr(_failed);
      return false;
    }
    final signature = '${user.uid}|$token|${currentLanguage.code}';
    if (!force && signature == _savedSignature) return true;

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_prefWebPushToken);
    final update = <Object, Object?>{
      FieldPath(['avisosWeb', token]): {
        'idioma': currentLanguage.code,
        'actualizado': FieldValue.serverTimestamp(),
      },
      'avisosWebActivos': true,
    };
    // Si el navegador cambió de identificador, se borra el anterior.
    if (previous != null && previous != token) {
      update[FieldPath(['avisosWeb', previous])] = FieldValue.delete();
    }
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .update(update);
    await prefs.setString(_prefWebPushToken, token);
    _savedSignature = signature;
    return true;
  }

  Future<void> _unregister() async {
    _savedSignature = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefWebPushToken);
      final user = FirebaseAuth.instance.currentUser;
      if (token == null || user == null) return;
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({FieldPath(['avisosWeb', token]): FieldValue.delete()});
      await prefs.remove(_prefWebPushToken);
    } catch (e) {
      debugPrint('No se pudo quitar el registro de avisos: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Mostrar una notificación desde la página
  // ---------------------------------------------------------------------------

  void _showLocal(String title, String body) {
    if (_permission != 'granted') return;
    try {
      web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          icon: 'icons/Icon-192.png',
          tag: 'zentory-vencimientos',
        ),
      );
    } catch (_) {
      // Chrome en Android no permite `new Notification()`: se usa el service
      // worker de Firebase.
      unawaited(_showWithServiceWorker(title, body));
    }
  }

  Future<void> _showWithServiceWorker(String title, String body) async {
    try {
      final JSAny? found = await web.window.navigator.serviceWorker
          .getRegistration('/firebase-cloud-messaging-push-scope')
          .toDart;
      if (found == null) return;
      final reg = found as web.ServiceWorkerRegistration;
      await reg
          .showNotification(
            title,
            web.NotificationOptions(
              body: body,
              icon: '/zentory/app/icons/Icon-192.png',
              tag: 'zentory-vencimientos',
            ),
          )
          .toDart;
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }
}
