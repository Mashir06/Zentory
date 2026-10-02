import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';
import 'zentory_repository.dart';
import '../l10n/strings.dart';

/// Autenticación con Firebase (correo y contraseña).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ZentoryRepository _repo = ZentoryRepository.instance;

  User? get currentUser => _auth.currentUser;

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
    await NotificationService.instance.clearAll();
    await _auth.signOut();
  }

  /// Traduce los errores más comunes de Firebase Auth.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return tr('Este correo ya está registrado. Intenta iniciar sesión.');
        case 'invalid-email':
          return tr('El formato del correo electrónico no es válido.');
        case 'weak-password':
          return tr('La contraseña debe tener al menos 6 caracteres');
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return tr('Correo o contraseña incorrectos');
        case 'too-many-requests':
          return tr('Demasiados intentos. Intenta más tarde.');
        case 'network-request-failed':
          return tr('Sin conexión a internet');
      }
      return tr('Error: {0}', [error.message ?? error.code]);
    }
    return tr('Error: {0}', [error]);
  }
}
