import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de la suscripción mensual de una tienda.
enum SubscriptionStatus {
  /// Pagada (o tienda antigua sin registro de suscripción).
  active,

  /// Vence en [Subscription.warningDays] días o menos.
  expiringSoon,

  /// Venció, pero sigue funcionando durante los días de gracia.
  grace,

  /// Suspendida: se puede ver el inventario, pero no agregar ni editar.
  suspended,
}

/// Suscripción de una tienda (`tiendas/{id}.suscripcion`). Solo NubikSoft
/// la modifica, desde el panel de administración.
///
/// ```
/// suscripcion: { pagadoHasta: Timestamp, estado: 'activa' | 'suspendida' | 'exenta' }
/// ```
///
/// `'exenta'` es una tienda con uso sin pago (se da desde el panel): siempre
/// activa, sin avisos de cobro y nunca se suspende.
class Subscription {
  const Subscription({
    this.paidUntil,
    this.manuallySuspended = false,
    this.exempt = false,
    this.hasRecord = false,
  });

  /// Días antes del vencimiento en que se muestra el aviso.
  static const warningDays = 5;

  /// Días después del vencimiento en que la tienda sigue funcionando.
  /// Debe coincidir con `firestore.rules` y con el panel web.
  static const graceDays = 5;

  /// Días hasta el primer cobro de una tienda nueva: un mes gratis y el
  /// primer mes, que se paga al terminar.
  static const trialDays = 60;

  final DateTime? paidUntil;
  final bool manuallySuspended;

  /// Uso sin pago dado por NubikSoft.
  final bool exempt;

  /// `false` en tiendas antiguas sin datos de suscripción.
  final bool hasRecord;

  factory Subscription.fromStoreData(Map<String, dynamic>? data) {
    final s = data?['suscripcion'];
    if (s is! Map) return const Subscription();
    final until = s['pagadoHasta'];
    return Subscription(
      paidUntil: until is Timestamp ? until.toDate() : null,
      manuallySuspended: s['estado'] == 'suspendida',
      exempt: s['estado'] == 'exenta',
      hasRecord: true,
    );
  }

  SubscriptionStatus statusAt(DateTime now) {
    if (exempt) return SubscriptionStatus.active;
    if (manuallySuspended) return SubscriptionStatus.suspended;
    final until = paidUntil;
    if (until == null) return SubscriptionStatus.active;
    if (now.isAfter(until.add(const Duration(days: graceDays)))) {
      return SubscriptionStatus.suspended;
    }
    if (now.isAfter(until)) return SubscriptionStatus.grace;
    if (until.difference(now) <= const Duration(days: warningDays)) {
      return SubscriptionStatus.expiringSoon;
    }
    return SubscriptionStatus.active;
  }

  SubscriptionStatus get status => statusAt(DateTime.now());

  /// Último día en que la tienda sigue funcionando si no paga.
  DateTime? get graceEnds =>
      paidUntil?.add(const Duration(days: graceDays));

  /// Fecha desde la que se muestra el aviso de pago.
  DateTime? get warningStarts =>
      paidUntil?.subtract(const Duration(days: warningDays));

  /// `false` cuando la tienda no puede agregar ni editar productos.
  bool get canEdit => status != SubscriptionStatus.suspended;
}

/// Un pago registrado por NubikSoft (`tiendas/{id}/pagos/{id}`).
class PaymentRecord {
  const PaymentRecord({
    required this.date,
    required this.months,
    this.amount,
    this.paidUntil,
    this.note = '',
  });

  final DateTime? date;
  final int months;
  final double? amount;
  final DateTime? paidUntil;
  final String note;

  factory PaymentRecord.fromData(Map<String, dynamic> data) {
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    final amount = data['monto'];
    final months = data['meses'];
    return PaymentRecord(
      date: time(data['fecha']),
      months: months is num ? months.toInt() : 1,
      amount: amount is num ? amount.toDouble() : null,
      paidUntil: time(data['hasta']),
      note: (data['nota'] as String?)?.trim() ?? '',
    );
  }
}
