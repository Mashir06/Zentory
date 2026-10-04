import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zentory/models/subscription.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  test('sin registro de suscripción: activa', () {
    expect(const Subscription().statusAt(now), SubscriptionStatus.active);
  });

  test('estados según la fecha de pago', () {
    Subscription paid(int days) =>
        Subscription(paidUntil: now.add(Duration(days: days)));
    expect(paid(20).statusAt(now), SubscriptionStatus.active);
    expect(paid(3).statusAt(now), SubscriptionStatus.expiringSoon);
    expect(paid(-2).statusAt(now), SubscriptionStatus.grace);
    expect(paid(-6).statusAt(now), SubscriptionStatus.suspended);
  });

  test('suspendida a mano aunque esté pagada', () {
    final s = Subscription(
      paidUntil: now.add(const Duration(days: 20)),
      manuallySuspended: true,
    );
    expect(s.statusAt(now), SubscriptionStatus.suspended);
  });

  test('uso sin pago: siempre activa, aunque tenga una fecha vencida', () {
    final s = Subscription.fromStoreData({
      'suscripcion': {
        'estado': 'exenta',
        'pagadoHasta': Timestamp.fromDate(now.subtract(const Duration(days: 90))),
      },
    });
    expect(s.statusAt(now), SubscriptionStatus.active);
    expect(s.exempt, isTrue);
    expect(
      Subscription.fromStoreData({
        'suscripcion': {'estado': 'exenta'},
      }).statusAt(now),
      SubscriptionStatus.active,
    );
  });

  test('fechas de aviso y de gracia', () {
    final until = DateTime(2026, 11, 1);
    final s = Subscription.fromStoreData({
      'suscripcion': {'pagadoHasta': Timestamp.fromDate(until)},
    });
    expect(s.hasRecord, isTrue);
    expect(s.warningStarts, DateTime(2026, 10, 27));
    expect(s.graceEnds, DateTime(2026, 11, 6));
    expect(Subscription.fromStoreData({}).hasRecord, isFalse);
  });

  test('pago registrado por el panel', () {
    final p = PaymentRecord.fromData({
      'meses': 2,
      'monto': 30,
      'nota': ' Yappy ',
      'fecha': Timestamp.fromDate(DateTime(2026, 10, 3)),
    });
    expect(p.months, 2);
    expect(p.amount, 30.0);
    expect(p.note, 'Yappy');
    expect(p.paidUntil, isNull);
  });

  test('mensualidad: \$25 si no hay monto en Firebase', () {
    expect(Subscription.fromStoreData({}).monthlyFee, 25);
    expect(
      Subscription.fromStoreData({
        'suscripcion': {'estado': 'activa'},
      }).monthlyFee,
      25,
    );
    expect(
      Subscription.fromStoreData({
        'suscripcion': {'monto': 30},
      }).monthlyFee,
      30,
    );
  });
}
