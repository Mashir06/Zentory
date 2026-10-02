import 'package:flutter_test/flutter_test.dart';
import 'package:zentory/models/product.dart';
import 'package:zentory/models/product_lots.dart';

Product _p(String id, String nombre, String vence, String cantidad) => Product(
      id: id,
      nombre: nombre,
      presentacion: 'N/A',
      fechaVencimiento: vence,
      fechaRegistro: 'N/A',
      cantidad: cantidad,
    );

void main() {
  final all = [
    _p('b', 'Leche Coast', '1/4/2028', '2'),
    _p('a', 'leche coast ', '1/1/2027', '3'),
    _p('c', 'Jugo', '15/8/2026', '1'),
    _p('d', 'Leche Coast', '', '4'),
  ];

  test('agrupa por nombre sin distinguir mayúsculas ni espacios', () {
    final groups = groupProducts(all);
    expect(groups.length, 2);
    final leche = groups.firstWhere((g) => g.key == 'leche coast');
    expect(leche.lots.map((l) => l.id), ['a', 'b', 'd']); // por vencimiento
    expect(leche.totalQty, 9);
  });

  test('numera los lotes sobre el inventario completo', () {
    final labels = lotLabels(all);
    expect(labels['a'], 'L001');
    expect(labels['b'], 'L002');
    expect(labels['d'], 'L003');
    expect(labels['c'], 'L001');
  });

  test('utilidades', () {
    expect(lotLabel(12), 'L012');
    expect(formatQty(3), '3');
    expect(formatQty(2.5), '2.5');
    expect(relativeExpiry(null), 'Sin fecha de vencimiento');
  });

  test('incluye productos del catálogo que aún no tienen lotes', () {
    final groups = groupProducts(
      [_p('x', 'Jugo', '15/8/2026', '1')],
      catalog: [
        CatalogItem(nombre: 'Jugo', presentacion: '250 ml'),
        CatalogItem(nombre: 'Pan', presentacion: '500 g'),
      ],
    );
    expect(groups.length, 2);
    final pan = groups.firstWhere((g) => g.key == 'pan');
    expect(pan.hasLots, isFalse);
    expect(pan.status, isNull);
    expect(pan.totalQty, 0);
    expect(pan.presentacion, '500 g');
    final jugo = groups.firstWhere((g) => g.key == 'jugo');
    expect(jugo.lots.length, 1);
    expect(jugo.presentacion, '250 ml');
  });

  test('mismo nombre con distinto código = productos distintos', () {
    Product lot(String id, String code) => Product(
          id: id,
          nombre: 'Coca-Cola',
          presentacion: 'N/A',
          fechaVencimiento: '1/1/2030',
          fechaRegistro: 'N/A',
          cantidad: '1',
          codigoBarras: code,
        );
    final groups = groupProducts(
      [lot('a', '111'), lot('b', '222'), lot('c', '111')],
      catalog: [
        CatalogItem(nombre: 'Coca-Cola', presentacion: '600 ml', codigoBarras: '111'),
        CatalogItem(nombre: 'Coca-Cola', presentacion: '2 L', codigoBarras: '222'),
      ],
    );
    expect(groups.length, 2);
    final chica = groups.firstWhere((g) => g.key == 'c:111');
    expect(chica.lots.length, 2);
    expect(chica.presentacion, '600 ml');
    expect(groups.firstWhere((g) => g.key == 'c:222').presentacion, '2 L');
  });
}
