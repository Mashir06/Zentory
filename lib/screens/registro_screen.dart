import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../l10n/strings.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final nombre = _nombre.text.trim();
    final correo = _correo.text.trim();
    final password = _password.text.trim();

    if (nombre.isEmpty || correo.isEmpty || password.isEmpty) {
      showMessage(context, tr('Por favor llena todos los campos'));
      return;
    }
    if (password.length < 6) {
      showMessage(context, tr('La contraseña debe tener al menos 6 caracteres'));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        nombre: nombre,
        correo: correo,
        password: password,
      );
      if (!mounted) return;
      showMessage(context, tr('Registro exitoso'));
      Routes.resetTo(context, Routes.session);
    } catch (e) {
      if (mounted) {
        showMessage(context, AuthService.messageFor(e), long: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    child: Image.asset(AppColors.logoAsset, width: 90),
                  ),
                  SizedBox(height: 20),
                  Text(
                    tr('Crear Cuenta'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('Únete a Zentory y controla tus productos'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 32),
                  LabeledField(
                    label: tr('Nombre completo'),
                    controller: _nombre,
                    hint: tr('Ej. Juan Pérez'),
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  LabeledField(
                    label: tr('Correo electrónico'),
                    controller: _correo,
                    hint: 'tu@correo.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  LabeledField(
                    label: tr('Contraseña'),
                    controller: _password,
                    hint: '••••••••',
                    obscureText: !_showPassword,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(),
                    suffix: IconButton(
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
                  SizedBox(height: 28),
                  LoadingButton(
                    label: tr('Registrarse'),
                    loading: _loading,
                    onPressed: _register,
                  ),
                  SizedBox(height: 24),
                  Text.rich(
                    TextSpan(
                      text: tr('¿Ya tienes cuenta? '),
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: tr('Inicia sesión'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.of(context).maybePop(),
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
