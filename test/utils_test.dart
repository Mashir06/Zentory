import 'package:flutter_test/flutter_test.dart';
import 'package:zentory/models/product.dart';
import 'package:zentory/utils/date_utils.dart';
import 'package:zentory/utils/image_utils.dart';

void main() {
  group('DateUtilsZ', () {
    test('lee fechas d/M/yyyy y dd/MM/yyyy', () {
      expect(DateUtilsZ.parse('5/7/2026'), DateTime(2026, 7, 5));
      expect(DateUtilsZ.parse('05/07/2026'), DateTime(2026, 7, 5));
      expect(DateUtilsZ.parse(''), isNull);
      expect(DateUtilsZ.parse('Selecciona la fecha'), isNull);
    });

    test('formatea como d/M/yyyy (compatible con la app Kotlin)', () {
      expect(DateUtilsZ.format(DateTime(2026, 7, 5)), '5/7/2026');
    });
  });

  group('ProductStatus', () {
    DateTime inDays(int n) {
      final t = DateUtilsZ.today();
      return DateTime(t.year, t.month, t.day + n);
    }

    test('clasifica por días restantes', () {
      expect(ProductStatus.fromExpiry(null), ProductStatus.noDate);
      expect(ProductStatus.fromExpiry(inDays(-1)), ProductStatus.expired);
      expect(ProductStatus.fromExpiry(inDays(0)), ProductStatus.expired);
      expect(ProductStatus.fromExpiry(inDays(1)), ProductStatus.expiring);
      expect(ProductStatus.fromExpiry(inDays(7)), ProductStatus.expiring);
      expect(ProductStatus.fromExpiry(inDays(8)), ProductStatus.good);
    });
  });

  test('javaStringHash replica String.hashCode() de Java', () {
    expect(javaStringHash(''), 0);
    expect(javaStringHash('a'), 97);
    expect(javaStringHash('hello'), 99162322);
    expect(javaStringHash('Leche Chiricana3'), isA<int>());
  });

  test('decodifica Base64 con saltos de línea (Base64.DEFAULT de Android)', () {
    final bytes = ImageUtils.decode('AQID\nBA==\n');
    expect(bytes, [1, 2, 3, 4]);
  });
}
