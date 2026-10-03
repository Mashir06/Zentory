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
/// suscripcion: { pagadoHasta: Timestamp, estado: 'activa' | 'suspendida' }
/// ```
class Subscription {
  const Subscription({this.paidUntil, this.manuallySuspended = false});

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

  factory Subscription.fromStoreData(Map<String, dynamic>? data) {
    final s = data?['suscripcion'];
    if (s is! Map) return const Subscription();
    final until = s['pagadoHasta'];
    return Subscription(
      paidUntil: until is Timestamp ? until.toDate() : null,
      manuallySuspended: s['estado'] == 'suspendida',
    );
  }

  SubscriptionStatus statusAt(DateTime now) {
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

  /// `false` cuando la tienda no puede agregar ni editar productos.
  bool get canEdit => status != SubscriptionStatus.suspended;
}
