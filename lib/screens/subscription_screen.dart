import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/subscription_banner.dart' show nubikSoftWhatsApp;

/// Ajustes > Suscripción y pagos: estado de la mensualidad de la tienda
/// activa, próxima fecha de pago, días de gracia e historial de pagos.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _Data {
  const _Data({
    required this.storeId,
    required this.storeName,
    required this.sub,
    required this.isAdmin,
    required this.payments,
  });

  final String? storeId;
  final String storeName;
  final Subscription sub;
  final bool isAdmin;
  final List<PaymentRecord>? payments;
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _repo = ZentoryRepository.instance;
  late Future<_Data> _future = _load();

  Future<_Data> _load() async {
    final storeId = await _repo.resolveActiveStoreId();
    if (storeId == null) {
      return _Data(
        storeId: null,
        storeName: '',
        sub: Subscription(),
        isAdmin: false,
        payments: null,
      );
    }
    final doc = await _repo.stores.doc(storeId).get();
    final store = Store.fromDoc(doc);
    final isAdmin = await _repo.isStoreAdmin(storeId);
    List<PaymentRecord>? payments;
    // El historial de pagos solo lo ve el administrador de la tienda.
    if (isAdmin) {
      try {
        payments = await _repo.fetchPayments(storeId);
      } catch (_) {
        payments = null;
      }
    }
    return _Data(
      storeId: storeId,
      storeName: store.nombre,
      sub: Subscription.fromStoreData(doc.data()),
      isAdmin: isAdmin,
      payments: payments,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // El error se muestra en pantalla.
    }
  }

  Future<void> _contact(String storeName) async {
    final message = tr(
        'Hola, quiero consultar o pagar la suscripción de Zentory de la tienda {0}.',
        [storeName]);
    final uri = Uri.parse(
      'https://wa.me/$nubikSoftWhatsApp?text=${Uri.encodeComponent(message)}',
    );
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) showMessage(context, tr('No se pudo abrir WhatsApp'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                subtitle: tr('Suscripción y pagos'),
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<_Data>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError || snap.data == null) {
                      return _Message(
                        icon: Icons.wifi_off,
                        text: tr('No se pudo cargar la suscripción. Revisa tu conexión a internet.'),
                        onRetry: _refresh,
                      );
                    }
                    final data = snap.data!;
                    if (data.storeId == null) {
                      return _Message(
                        icon: Icons.storefront_outlined,
                        text: tr('No perteneces a ninguna tienda.'),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: _content(data),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(_Data data) {
    final sub = data.sub;
    final status = sub.status;
    final until = sub.paidUntil;
    final days = until == null ? null : DateUtilsZ.daysFromToday(until);

    final (Color color, IconData icon, String label, String detail) =
        _statusInfo(sub, status, days);

    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      children: [
        Text(
          data.storeName,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          tr('Plan mensual de Zentory'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        SizedBox(height: 16),

        // Estado actual
        ZCard(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Estado'),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Fechas
        if (!sub.exempt && until != null)
          ZCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.event,
                  label: tr('Próximo pago'),
                  value: DateUtilsZ.longDate(until),
                  hint: _daysText(days!),
                ),
                _InfoRow(
                  icon: Icons.notifications_active_outlined,
                  label: tr('Aviso de pago desde'),
                  value: DateUtilsZ.longDate(sub.warningStarts!),
                ),
                _InfoRow(
                  icon: Icons.hourglass_bottom,
                  label: tr('Último día de gracia'),
                  value: DateUtilsZ.longDate(sub.graceEnds!),
                  hint: tr('Después, la tienda queda en solo lectura'),
                ),
                _InfoRow(
                  icon: sub.canEdit ? Icons.edit_outlined : Icons.lock_outline,
                  label: tr('Agregar y editar productos'),
                  value: sub.canEdit ? tr('Permitido') : tr('Bloqueado'),
                  valueColor:
                      sub.canEdit ? AppColors.primary : AppColors.danger,
                  last: true,
                ),
              ],
            ),
          ),

        // Último pago
        if (data.payments != null && data.payments!.isNotEmpty) ...[
          SizedBox(height: 12),
          ZCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _InfoRow(
              icon: Icons.check_circle_outline,
              label: tr('Último pago'),
              value: _paymentTitle(data.payments!.first),
              hint: data.payments!.first.date == null
                  ? null
                  : tr('Registrado el {0}',
                      [DateUtilsZ.longDate(data.payments!.first.date!)]),
              last: true,
            ),
          ),
        ],

        SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _contact(data.storeName),
          icon: Icon(Icons.chat_outlined, size: 18),
          label: Text(sub.exempt
              ? tr('Contactar a Zentory por WhatsApp')
              : tr('Pagar o consultar por WhatsApp')),
        ),

        // Cómo funciona
        _sectionTitle(tr('Cómo funciona el pago')),
        ZCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet(tr('Se paga una mensualidad por tienda, al final de cada mes de uso. No hay pago inicial.')),
              _Bullet(tr('La app te avisa {0} días antes de la fecha de pago.',
                  [Subscription.warningDays])),
              _Bullet(tr('Si la fecha pasa, tienes {0} días de gracia para pagar sin perder nada.',
                  [Subscription.graceDays])),
              _Bullet(tr('Después, la tienda queda en solo lectura: puedes ver tu inventario, pero no agregar ni editar productos.')),
              _Bullet(tr('Tus datos nunca se borran. Al registrar el pago, la tienda se reactiva al instante.'),
                  last: true),
            ],
          ),
        ),

        // Historial (solo administrador)
        if (data.isAdmin) ...[
          _sectionTitle(tr('Historial de pagos')),
          ZCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: data.payments == null
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      tr('No se pudo cargar el historial.'),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : data.payments!.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          tr('Todavía no hay pagos registrados.'),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < data.payments!.length; i++)
                            _paymentRow(data.payments![i],
                                last: i == data.payments!.length - 1),
                        ],
                      ),
          ),
        ] else ...[
          SizedBox(height: 12),
          Text(
            tr('El historial de pagos solo lo ve el administrador de la tienda.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        SizedBox(height: 24),
      ],
    );
  }

  (Color, IconData, String, String) _statusInfo(
      Subscription sub, SubscriptionStatus status, int? days) {
    if (sub.exempt) {
      return (
        AppColors.info,
        Icons.workspace_premium_outlined,
        tr('Sin pago'),
        tr('Zentory le dio a esta tienda uso sin pago. No tiene cobros ni vencimientos.'),
      );
    }
    if (!sub.hasRecord || sub.paidUntil == null) {
      return (
        AppColors.primary,
        Icons.check_circle_outline,
        tr('Activa'),
        tr('Tu tienda todavía no tiene fechas de pago registradas.'),
      );
    }
    return switch (status) {
      SubscriptionStatus.active => (
          AppColors.primary,
          Icons.check_circle_outline,
          tr('Al día'),
          tr('Todo en orden. Faltan {0} días para el próximo pago.', [days]),
        ),
      SubscriptionStatus.expiringSoon => (
          AppColors.warning,
          Icons.schedule,
          tr('Por vencer'),
          days == 0
              ? tr('El pago vence hoy.')
              : tr('El pago vence en {0} días.', [days]),
        ),
      SubscriptionStatus.grace => (
          AppColors.alertBrown,
          Icons.warning_amber_rounded,
          tr('Vencida (en gracia)'),
          tr('El pago venció. La tienda sigue funcionando hasta el {0}.',
              [DateUtilsZ.longDate(sub.graceEnds!)]),
        ),
      SubscriptionStatus.suspended => (
          AppColors.danger,
          Icons.lock_outline,
          tr('Suspendida'),
          tr('Puedes ver tu inventario, pero no agregar ni editar productos hasta pagar.'),
        ),
    };
  }

  String _daysText(int days) {
    if (days == 0) return tr('Hoy');
    if (days == 1) return tr('Mañana');
    if (days > 1) return tr('En {0} días', [days]);
    if (days == -1) return tr('Venció ayer');
    return tr('Venció hace {0} días', [-days]);
  }

  String _paymentTitle(PaymentRecord p) {
    final months = p.months == 1 ? tr('1 mes') : tr('{0} meses', [p.months]);
    final amount = p.amount == null ? '' : ' · ${p.amount!.toStringAsFixed(2)} USD';
    return '$months$amount';
  }

  Widget _paymentRow(PaymentRecord p, {required bool last}) {
    final parts = <String>[
      if (p.date != null) DateUtilsZ.longDate(p.date!),
      if (p.paidUntil != null)
        tr('cubre hasta el {0}', [DateUtilsZ.longDate(p.paidUntil!)]),
      if (p.note.isNotEmpty) p.note,
    ];
    return _InfoRow(
      icon: Icons.receipt_long_outlined,
      label: parts.join(' · '),
      value: _paymentTitle(p),
      last: last,
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null) ...[
                  SizedBox(height: 2),
                  Text(
                    hint!,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.last = false});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSoft,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40),
            SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(tr('Reintentar'))),
            ],
          ],
        ),
      ),
    );
  }
}
