import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Formatos de fecha en español, inglés y chino.
  await initializeDateFormatting();
  await AppSettings.instance.load();
  await NotificationService.instance.init();
  // Borra el calendario del antiguo "respaldo en calendario", si existía.
  unawaited(NotificationService.instance.cleanupLegacyCalendar());
  runApp(const ZentoryApp());
}
