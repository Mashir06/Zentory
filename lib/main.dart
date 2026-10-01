import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');
  await NotificationService.instance.init();
  // Borra el calendario del antiguo "respaldo en calendario", si existía.
  unawaited(NotificationService.instance.cleanupLegacyCalendar());
  // FCM: no se espera, para no retrasar el arranque si no hay servicios de
  // Google en el teléfono.
  unawaited(PushService.instance.init());
  runApp(const ZentoryApp());
}
