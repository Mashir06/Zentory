import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Todo lo que no depende de lo demás se prepara a la vez: arranca antes.
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    // Formatos de fecha en español, inglés y chino.
    initializeDateFormatting(),
    AppSettings.instance.load(),
  ]);
  if (kIsWeb) {
    // En la web, guarda una copia de los datos en el navegador (como hace
    // Android): la app abre más rápido y aguanta cortes de internet.
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
  }
  await NotificationService.instance.init();
  runApp(const ZentoryApp());
}
