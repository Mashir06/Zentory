import 'package:flutter_test/flutter_test.dart';
import 'package:zentory/models/user_access.dart';
import 'package:zentory/services/zentory_repository.dart';

void main() {
  test('cuenta nueva sin aprobar', () {
    expect(ZentoryRepository.isApprovedData({'aprobado': false}), isFalse);
    expect(
      AccessState.fromData({'aprobado': false, 'estadoAcceso': 'pendiente'}),
      AccessState.pending,
    );
  });

  test('cuenta aprobada desde el panel', () {
    expect(ZentoryRepository.isApprovedData({'aprobado': true}), isTrue);
    expect(
      AccessState.fromData({'aprobado': true, 'estadoAcceso': 'aprobado'}),
      AccessState.approved,
    );
  });

  test('cuentas antiguas sin el campo siguen entrando', () {
    expect(ZentoryRepository.isApprovedData({'nombre': 'Ana'}), isTrue);
  });

  test('rechazada y bloqueada no entran', () {
    expect(
      AccessState.fromData({'aprobado': false, 'estadoAcceso': 'rechazado'}),
      AccessState.rejected,
    );
    expect(
      AccessState.fromData({'aprobado': false, 'estadoAcceso': 'bloqueado'}),
      AccessState.blocked,
    );
  });
}
