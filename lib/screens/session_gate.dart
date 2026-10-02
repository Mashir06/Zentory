import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../l10n/strings.dart';

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
      // de mandarlo a crear una. Otros errores no bloquean la entrada.
      if (ZentoryRepository.isNetworkError(e)) {
        if (mounted) setState(() => _error = '$e');
        return;
      }
      debugPrint('No se pudo comprobar la tienda: $e');
      storeId = null;
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
              Image.asset(AppColors.logoAsset, width: 120),
              SizedBox(height: 24),
              if (_error == null)
                CircularProgressIndicator()
              else ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    tr('No se pudo comprobar tu tienda. Revisa tu conexión a internet.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(height: 16),
                FilledButton(onPressed: _route, child: Text(tr('Reintentar'))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
