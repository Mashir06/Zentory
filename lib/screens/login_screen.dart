import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../l10n/strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final correo = _correo.text.trim();
    final password = _password.text.trim();
    if (correo.isEmpty || password.isEmpty) {
      showMessage(context, tr('Por favor llena todos los campos'));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithEmail(correo, password);
      if (!mounted) return;
      showMessage(context, tr('¡Bienvenido!'));
      Routes.resetTo(context, Routes.session);
    } catch (e) {
      if (mounted) showMessage(context, AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final ok = await AuthService.instance.signInWithGoogle();
      if (ok && mounted) Routes.resetTo(context, Routes.session);
    } catch (e) {
      if (mounted) {
        showMessage(context, AuthService.messageFor(e), long: true);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty) {
      showMessage(context, tr('Por favor, ingresa tu correo primero'));
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(correo);
      if (mounted) {
        showMessage(
          context,
          tr('Se ha enviado un correo para restablecer tu contraseña'),
          long: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          tr('Error al enviar correo: {0}', [AuthService.messageFor(e)]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Image.asset(
                      'assets/images/logozentory.png',
                      width: 110,
                      semanticLabel: tr('Logo de Zentory'),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    tr('¡Bienvenido de nuevo!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('Iniciar sesión para continuar'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 32),
                  LabeledField(
                    label: tr('Correo electrónico'),
                    controller: _correo,
                    hint: tr('Ingresa tu correo electrónico'),
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  LabeledField(
                    label: tr('Contraseña'),
                    controller: _password,
                    hint: tr('Ingresa tu contraseña'),
                    obscureText: !_showPassword,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    suffix: IconButton(
                      tooltip: _showPassword
                          ? tr('Ocultar contraseña')
                          : tr('Mostrar contraseña'),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: Text(tr('¿Olvidaste tu contraseña?')),
                    ),
                  ),
                  SizedBox(height: 8),
                  LoadingButton(
                    label: tr('Iniciar sesión'),
                    loading: _loading,
                    onPressed: _login,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'O',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _googleLoading ? null : _loginWithGoogle,
                    icon: _googleLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'G',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.blue,
                            ),
                          ),
                    label: Text(tr('Iniciar sesión con Google')),
                  ),
                  SizedBox(height: 28),
                  Text.rich(
                    TextSpan(
                      text: tr('¿No tienes una cuenta? '),
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: tr('Regístrate aquí'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.of(context)
                                .pushNamed(Routes.register),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
