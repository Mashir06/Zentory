import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../models/user_access.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Pantalla de una cuenta sin acceso: recién registrada (espera a que
/// NubikSoft la apruebe desde el panel web), rechazada o bloqueada. En cuanto
/// se aprueba, la app sigue sola (crear o unirse a una tienda).
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static final _zentoryPage = Uri.parse('https://www.nubiksoft.com/zentory/');

  StreamSubscription<AccessState?>? _sub;
  AccessState _state = AccessState.pending;
  bool _leaving = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _sub = ZentoryRepository.instance.watchCurrentUserAccess().listen(
      (state) {
        if (state == AccessState.approved) {
          _continue();
        } else if (state != null && mounted) {
          setState(() => _state = state);
        }
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

  Future<void> _requestAgain() async {
    setState(() => _requesting = true);
    try {
      await ZentoryRepository.instance.requestAccessAgain();
      if (mounted) showMessage(context, tr('Solicitud enviada'));
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('No se pudo enviar la solicitud. Revisa tu conexión.'));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
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
    final (Color color, IconData icon, String title, String text, String status) =
        switch (_state) {
      AccessState.rejected => (
          AppColors.danger,
          Icons.cancel_outlined,
          tr('Tu solicitud fue rechazada'),
          tr('El equipo de Zentory no aprobó tu cuenta. Si crees que es un error, contáctanos o vuelve a enviar la solicitud.'),
          tr('Solicitud rechazada'),
        ),
      AccessState.blocked => (
          AppColors.danger,
          Icons.block,
          tr('Tu cuenta está bloqueada'),
          tr('No puedes usar Zentory con esta cuenta. Contacta a Zentory para más información.'),
          tr('Cuenta bloqueada'),
        ),
      _ => (
          AppColors.warning,
          Icons.hourglass_top_rounded,
          tr('Espere la confirmación de Zentory'),
          tr('Tu cuenta fue creada. El equipo de Zentory debe aprobarla antes de que puedas usar la app. Esta pantalla se quitará sola en cuanto te den acceso.'),
          tr('Esperando aprobación'),
        ),
    };
    final waiting = _state == AccessState.pending;
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
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 38,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    text,
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
                        if (waiting)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          Icon(icon, color: color, size: 22),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
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
                  if (_state == AccessState.rejected) ...[
                    FilledButton.icon(
                      onPressed: _requesting ? null : _requestAgain,
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text(tr('Volver a solicitar acceso')),
                    ),
                    SizedBox(height: 8),
                  ],
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
