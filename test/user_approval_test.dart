import 'package:flutter_test/flutter_test.dart';
import 'package:zentory/services/zentory_repository.dart';

void main() {
  test('cuenta nueva sin aprobar', () {
    expect(ZentoryRepository.isApprovedData({'aprobado': false}), isFalse);
  });

  test('cuenta aprobada desde el panel', () {
    expect(ZentoryRepository.isApprovedData({'aprobado': true}), isTrue);
  });

  test('cuentas antiguas sin el campo siguen entrando', () {
    expect(ZentoryRepository.isApprovedData({'nombre': 'Ana'}), isTrue);
  });
}
