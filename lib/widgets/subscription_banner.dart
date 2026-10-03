import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'common.dart';

/// WhatsApp de NubikSoft para pagos y renovaciones (código de país de Panamá).
const nubikSoftWhatsApp = '50761857395';

/// Aviso de la suscripción de la tienda: no muestra nada si está al día.
class SubscriptionBanner extends StatefulWidget {
  const SubscriptionBanner({super.key, required this.storeId});

  final String storeId;

  @override
  State<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<SubscriptionBanner> {
  Subscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SubscriptionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) _load();
  }

  Future<void> _load() async {
    try {
      final sub =
          await ZentoryRepository.instance.fetchSubscription(widget.storeId);
      if (mounted) setState(() => _sub = sub);
    } catch (_) {
      // Sin conexión no se muestra el aviso.
    }
  }

  Future<void> _contact() async {
    final message = tr('Hola, quiero renovar la suscripción de Zentory de la tienda {0}.', [widget.storeId]);
    final uri = Uri.parse(
      'https://wa.me/$nubikSoftWhatsApp?text=${Uri.encodeComponent(message)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showMessage(context, tr('No se pudo abrir WhatsApp'));
  }

  @override
  Widget build(BuildContext context) {
    final sub = _sub;
    if (sub == null) return SizedBox.shrink();
    final status = sub.status;
    if (status == SubscriptionStatus.active) return SizedBox.shrink();

    final until = sub.paidUntil;
    final date = until == null ? '' : DateUtilsZ.format(until);
    final (Color color, IconData icon, String title, String text) = switch (status) {
      SubscriptionStatus.expiringSoon => (
          AppColors.warning,
          Icons.schedule,
          tr('Tu suscripción vence pronto'),
          tr('Vence el {0}. Renuévala para seguir agregando y editando productos.', [date]),
        ),
      SubscriptionStatus.grace => (
          AppColors.alertBrown,
          Icons.warning_amber_rounded,
          tr('Tu suscripción venció'),
          tr('Venció el {0}. Tienes unos días de gracia antes de que la tienda pase a solo lectura.', [date]),
        ),
      _ => (
          AppColors.danger,
          Icons.lock_outline,
          tr('Suscripción suspendida'),
          tr('Puedes ver tu inventario, pero no agregar ni editar productos. Renueva la suscripción para reactivar la tienda.'),
        ),
    };

    return ZCard(
      color: color,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(14, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.onColor),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.onColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(color: AppColors.onColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _contact,
              style: TextButton.styleFrom(foregroundColor: AppColors.onColor),
              icon: Icon(Icons.chat_outlined, size: 18),
              label: Text(tr('Renovar por WhatsApp')),
            ),
          ),
        ],
      ),
    );
  }
}
