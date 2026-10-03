import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Pantalla de una cuenta recién registrada: espera a que NubikSoft la apruebe
/// desde el panel web. En cuanto se aprueba, la app sigue sola (crear o
/// unirse a una tienda).
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static final _zentoryPage = Uri.parse('https://www.nubiksoft.com/zentory/');

  StreamSubscription<bool>? _sub;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _sub = ZentoryRepository.instance.watchCurrentUserApproval().listen(
      (approved) {
        if (approved) _continue();
      },
      // Sin internet el aviso llega cuando vuelva la conexión.
      onError: (Object e) => debugPrint('Aprobación: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _continue() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _sub?.cancel();
    Routes.resetTo(context, Routes.session);
  }

  Future<void> _contact() async {
    var ok = false;
    try {
      ok = await launchUrl(_zentoryPage, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      showMessage(context, tr('No se pudo abrir la página de Zentory'));
    }
  }

  Future<void> _signOut() async {
    _leaving = true;
    await _sub?.cancel();
    await AuthService.instance.signOut();
    if (mounted) Routes.resetTo(context, Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '';
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(AppColors.logoAsset, width: 100),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        size: 38,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    tr('Espere la confirmación de Zentory'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    tr('Tu cuenta fue creada. El equipo de Zentory debe aprobarla antes de que puedas usar la app. Esta pantalla se quitará sola en cuanto te den acceso.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 28),
                  ZCard(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Esperando aprobación'),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                SizedBox(height: 2),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _contact,
                    icon: Icon(Icons.open_in_new, size: 18),
                    label: Text(tr('Contactar a Zentory')),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      tr('Cerrar Sesión'),
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
