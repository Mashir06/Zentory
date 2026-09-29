import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/store_dialogs.dart';

/// Acciones compartidas por la selección de tienda y el onboarding.
mixin _StoreSetupActions<T extends StatefulWidget> on State<T> {
  final _repo = ZentoryRepository.instance;

  Future<void> createStore() async {
    String? created;
    final ok = await showStoreFormDialog(
      context,
      title: 'Crear una nueva tienda',
      onSubmit: (nombre, ubicacion) async {
        created = await _repo.createStore(nombre: nombre, ubicacion: ubicacion);
      },
    );
    if (!ok || !mounted) return;
    showMessage(context, "Tienda '$created' creada", long: true);
    Routes.resetTo(context, Routes.home);
  }

  Future<void> joinStore() async {
    String? storeName;
    final ok = await showJoinStoreDialog(
      context,
      onSubmit: (code) async => storeName = await _repo.joinStore(code),
    );
    if (!ok || !mounted) return;
    showMessage(context, 'Te has unido a $storeName');
    Routes.resetTo(context, Routes.home);
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    if (mounted) Routes.resetTo(context, Routes.login);
  }
}

/// Pantalla que ve el usuario cuando todavía no pertenece a ninguna tienda.
class StoreSelectionScreen extends StatefulWidget {
  const StoreSelectionScreen({super.key});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen>
    with _StoreSetupActions {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/logozentory.png', width: 100),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡Bienvenido a Zentory!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para comenzar a gestionar tus productos, necesitas estar '
                    'vinculado a una tienda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 36),
                  _OptionCard(
                    icon: Icons.storefront_outlined,
                    title: 'Crear una nueva tienda',
                    subtitle: 'Configura tu propio inventario',
                    onTap: createStore,
                  ),
                  const SizedBox(height: 16),
                  _OptionCard(
                    icon: Icons.group_add_outlined,
                    title: 'Unirse a una tienda',
                    subtitle: 'Ingresa con un código de invitación',
                    onTap: joinStore,
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: signOut,
                    child: const Text(
                      'Cerrar Sesión',
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Variante de bienvenida con botones grandes (ruta "onboarding").
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with _StoreSetupActions {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¡Bienvenido a Zentory!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para comenzar, necesitas estar vinculado a un Minisuper.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: createStore,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Crear mi propio Minisuper'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'o',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: joinStore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('Unirse con código de invitación'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: signOut,
                    child: const Text(
                      'Cerrar Sesión',
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
