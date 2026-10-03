import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_access.dart';
import '../routes.dart';
import 'zentory_repository.dart';

/// Vigila el acceso de la cuenta mientras la app está abierta: si NubikSoft la
/// bloquea o le quita el acceso desde el panel web, la app pasa al instante a
/// la pantalla de espera, esté donde esté el usuario.
class AccessGuard extends NavigatorObserver {
  AccessGuard._();
  static final AccessGuard instance = AccessGuard._();

  final navigatorKey = GlobalKey<NavigatorState>();

  /// Pantallas donde no hace falta tener acceso.
  static const _openRoutes = {
    Routes.session,
    Routes.login,
    Routes.register,
    Routes.pendingApproval,
  };

  String? _current;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AccessState?>? _accessSub;

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      _accessSub?.cancel();
      _accessSub = null;
      if (user == null) return;
      _accessSub = ZentoryRepository.instance.watchUserAccess(user.uid).listen(
        (state) {
          if (state != null && state != AccessState.approved) _lock();
        },
        // Sin conexión no se hace nada; se vuelve a comprobar al reconectar.
        onError: (Object _) {},
      );
    });
  }

  void _lock() {
    if (_openRoutes.contains(_current)) return;
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(Routes.pendingApproval, (_) => false);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _current = route.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) _current = newRoute.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      _current = previousRoute.settings.name;
    }
  }
}
