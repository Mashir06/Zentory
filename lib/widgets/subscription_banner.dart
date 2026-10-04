import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'common.dart';

/// Aviso de la suscripción de la tienda: no muestra nada si está al día.
///
/// Solo informa. Por la política de pagos de Google Play no tiene botón ni
/// enlace para pagar: el enlace de pago lo envía NubikSoft por WhatsApp.
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
          tr('Puedes ver tu inventario, pero no agregar ni editar productos. La tienda se reactiva en cuanto se registre el pago.'),
        ),
    };

    return ZCard(
      color: color,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
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
          SizedBox(height: 8),
          Text(
            tr('NubikSoft te enviará el enlace de pago por WhatsApp.'),
            style: TextStyle(
              color: AppColors.onColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
