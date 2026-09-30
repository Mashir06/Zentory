import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'device_settings.dart';
import 'notification_service.dart';
import 'zentory_repository.dart';

/// Autenticación con Firebase (correo/contraseña y Google).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ZentoryRepository _repo = ZentoryRepository.instance;

  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<void> _initGoogle() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: DefaultFirebaseOptions.googleServerClientId,
    );
    _googleInitialized = true;
  }

  Future<void> signInWithEmail(String correo, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: correo,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      // Asegurar que el documento del usuario exista en Firestore
      await _repo.ensureUserDoc(user, fallbackEmail: correo);
    }
  }

  /// Devuelve `false` si el usuario canceló el inicio de sesión.
  Future<bool> signInWithGoogle() async {
    if (!await DeviceSettings.hasGooglePlayServices()) {
      throw const GoogleUnavailableException(
        'Tu teléfono no tiene los servicios de Google Play, que son necesarios '
        'para iniciar sesión con Google (pasa en muchos teléfonos de versión '
        'china). Inicia sesión con correo y contraseña; si tu cuenta es de '
        'Google, usa "¿Olvidaste tu contraseña?" para crear una contraseña.',
      );
    }
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // Si la huella (SHA-1) de la app no está registrada en Firebase, Android
      // suele informar el error como "cancelado" ("[16] Account reauth
      // failed"). Solo se ignora cuando fue el usuario quien canceló.
      final desc = (e.description ?? '').toLowerCase();
      final isConfigError = desc.contains('reauth') ||
          desc.contains('[16]') ||
          desc.contains('developer') ||
          desc.contains('[10]');
      if (e.code == GoogleSignInExceptionCode.canceled && !isConfigError) {
        return false;
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleUnavailableException(
        'Google no devolvió las credenciales. Revisa que la huella SHA-1 de '
        'esta versión de la app esté registrada en Firebase.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) await _repo.ensureUserDoc(user);
    return true;
  }

  Future<void> register({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      // La contraseña NO se guarda en Firestore; Firebase Auth la gestiona.
      await _repo.createUserDoc(user, nombre, correo);
    }
  }

  Future<void> sendPasswordReset(String correo) =>
      _auth.sendPasswordResetEmail(email: correo);

  Future<void> signOut() async {
    // Las alertas pertenecen a la tienda de este usuario.
    await NotificationService.instance.cancelExpiryAlerts();
    await _auth.signOut();
    try {
      await _initGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // No había sesión de Google.
    }
  }

  /// Traduce los errores más comunes de Firebase Auth.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Este correo ya está registrado. Intenta iniciar sesión.';
        case 'invalid-email':
          return 'El formato del correo electrónico no es válido.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde.';
        case 'network-request-failed':
          return 'Sin conexión a internet';
      }
      return 'Error: ${error.message ?? error.code}';
    }
    if (error is GoogleUnavailableException) return error.message;
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'No se pudo iniciar sesión con Google: esta versión de la app '
              'no está autorizada en Firebase (falta registrar su huella '
              'SHA-1). Mientras tanto, usa correo y contraseña. '
              '(${error.description ?? error.code.name})';
        case GoogleSignInExceptionCode.uiUnavailable:
          return 'No se pudo mostrar la ventana de Google. Revisa que tengas '
              'una cuenta de Google en el teléfono y los servicios de Google '
              'Play actualizados.';
        default:
          return 'Error de Google: ${error.description ?? error.code.name}';
      }
    }
    return 'Error: $error';
  }
}

/// Error de inicio con Google con un mensaje listo para mostrar.
class GoogleUnavailableException implements Exception {
  const GoogleUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}
