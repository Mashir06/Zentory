import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/common.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = [
    (
      '¿Cómo agrego un nuevo producto?',
      "Para agregar un producto, ve a la sección de 'Productos' y presiona el "
          "botón '+' o utiliza el escáner QR para registrarlo rápidamente.",
    ),
    (
      '¿Cómo invito a alguien a mi tienda?',
      "En tu perfil, encontrarás el 'Código de Invitación' de tu tienda. "
          'Compártelo con tus empleados para que puedan unirse desde su '
          'propia cuenta.',
    ),
    (
      '¿Puedo tener varias tiendas?',
      'Sí, puedes crear múltiples tiendas o sucursales desde tu perfil y '
          'alternar entre ellas en cualquier momento.',
    ),
    (
      '¿Cómo cambio mi contraseña?',
      'Por ahora, el cambio de contraseña se gestiona a través del inicio de '
          'sesión con Google o el sistema de recuperación de Firebase en la '
          'pantalla de login.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SimpleHeader(title: 'Preguntas Frecuentes'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final (q, a) in _faqs)
                      ZCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a,
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
