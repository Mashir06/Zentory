import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../l10n/strings.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static List<(String, String)> get _faqs => [
    (
      tr('¿Cómo agrego un nuevo producto?'),
      tr('Toca el botón \'+\' para agregar un producto. En el formulario puedes escanear su código de barras: si el producto ya está registrado, pasarás directo a agregarle un lote.'),
    ),
    (
      tr('¿Cómo invito a alguien a mi tienda?'),
      tr('En tu perfil, encontrarás el \'Código de Invitación\' de tu tienda. Compártelo con tus empleados para que puedan unirse desde su propia cuenta.'),
    ),
    (
      tr('¿Puedo tener varias tiendas?'),
      tr('Sí, puedes crear múltiples tiendas o sucursales desde tu perfil y alternar entre ellas en cualquier momento.'),
    ),
    (
      tr('¿Cómo cambio mi contraseña?'),
      tr('Ve a Configuración > Privacidad y Seguridad > Cambiar Contraseña, o usa "¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión. Te llegará un correo para crear una nueva.'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              SimpleHeader(title: tr('Preguntas Frecuentes')),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    for (final (q, a) in _faqs)
                      ZCard(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              a,
                              style: TextStyle(
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
