import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../services/zentory_repository.dart';
import '../widgets/common.dart';

/// Decide la pantalla inicial (equivale a "check_session" + "check_store"):
/// sin sesión → login; con sesión y tienda → inicio; sin tienda → selección.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  String? _error;

  /// Sin tienda no se entra a la app: se va obligatoriamente a la pantalla
  /// de crear o unirse a una tienda.
  Future<void> _route() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) Routes.resetTo(context, Routes.login);
      return;
    }
    if (_error != null) setState(() => _error = null);
    String? storeId;
    try {
      storeId = await ZentoryRepository.instance.resolveActiveStoreId();
    } catch (e) {
      // Sin conexión no se sabe si tiene tienda: se ofrece reintentar en vez
      // de mandarlo a crear una.
      if (mounted) setState(() => _error = '$e');
      return;
    }
    if (!mounted) return;
    Routes.resetTo(
      context,
      storeId != null ? Routes.home : Routes.storeSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logozentory.png', width: 120),
              const SizedBox(height: 24),
              if (_error == null)
                const CircularProgressIndicator()
              else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'No se pudo comprobar tu tienda. Revisa tu conexión a '
                    'internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _route, child: const Text('Reintentar')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
