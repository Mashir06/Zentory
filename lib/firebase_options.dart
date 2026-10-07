// Opciones de Firebase para el proyecto "zentory-base".
//
// Android: valores de android/app/google-services.json.
// Web: la app web registrada en Firebase (la misma que usa el panel de
// NubikSoft). Si agregas iOS, regenera este archivo con:
//   dart pub global activate flutterfire_cli && flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Zentory solo está configurado para Android. '
          'Ejecuta "flutterfire configure" para agregar otras plataformas.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBRRYtBVWeS_9e-kn-8dYUKVCtRqagJYSw',
    appId: '1:794054120945:android:a50a962c8de657d7c8a050',
    messagingSenderId: '794054120945',
    projectId: 'zentory-base',
    storageBucket: 'zentory-base.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4Ul2Du4OrpHVrpbecSIMqdkZzskpaMAE',
    appId: '1:794054120945:web:0b24be636e6e7088c8a050',
    messagingSenderId: '794054120945',
    projectId: 'zentory-base',
    authDomain: 'zentory-base.firebaseapp.com',
    storageBucket: 'zentory-base.firebasestorage.app',
    measurementId: 'G-7S1THYLZRK',
  );

}
