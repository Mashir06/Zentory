import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
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
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final idToken = account.authentication.idToken;
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
    if (error is GoogleSignInException) {
      return 'Error de Google: ${error.description ?? error.code.name}';
    }
    return 'Error: $error';
  }
}
