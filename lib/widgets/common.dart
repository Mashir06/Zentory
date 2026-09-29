import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/app_colors.dart';

/// Fondo degradado oscuro usado en todas las pantallas.
class ZentoryBackground extends StatelessWidget {
  const ZentoryBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: child,
    );
  }
}

/// Encabezado con el logo, "ZENTORY" y "Control de caducidad".
class ZentoryHeader extends StatelessWidget {
  const ZentoryHeader({
    super.key,
    this.onBack,
    this.trailing,
    this.subtitle = 'Control de caducidad',
  });

  final VoidCallback? onBack;
  final Widget? trailing;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Atrás',
                )
              else
                const SizedBox(width: 8),
              Image.asset('assets/images/logozentory.png', width: 40, height: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZENTORY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.surface),
      ],
    );
  }
}

/// Encabezado simple con botón atrás y título (pantallas de ajustes).
class SimpleHeader extends StatelessWidget {
  const SimpleHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Atrás',
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Barra de navegación inferior: Inicio, Productos, Escanear, Calendario.
class ZentoryBottomNav extends StatelessWidget {
  const ZentoryBottomNav({super.key, required this.current});

  final String current;

  static const _items = [
    (Routes.home, Icons.home_rounded, 'Inicio'),
    (Routes.productos, Icons.inventory_2_outlined, 'Productos'),
    (Routes.scan, Icons.qr_code_scanner, 'Escanear'),
    (Routes.calendar, Icons.calendar_month_outlined, 'Calendario'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _items.indexWhere((i) => i.$1 == current);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
      child: NavigationBar(
        height: 68,
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => Routes.goToTab(context, _items[i].$1),
        destinations: [
          for (final item in _items)
            NavigationDestination(icon: Icon(item.$2), label: item.$3),
        ],
      ),
    );
  }
}

/// Muestra un mensaje breve (equivale a los Toast de Android).
void showMessage(BuildContext context, String message, {bool long = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: long ? 4 : 2),
      ),
    );
}

/// Diálogo de confirmación. Devuelve `true` si el usuario confirma.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
  Color confirmColor = AppColors.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSoft),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tarjeta redondeada con el color de superficie.
class ZCard extends StatelessWidget {
  const ZCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
