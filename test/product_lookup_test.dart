import 'package:flutter_test/flutter_test.dart';
import 'package:zentory/services/product_lookup_service.dart';

void main() {
  group('ProductLookupService.parse', () {
    test('prefiere el nombre en español y usa quantity', () {
      final p = ProductLookupService.parse({
        'status': 1,
        'product': {
          'product_name': 'Whole milk',
          'product_name_es': 'Leche entera',
          'quantity': '1 L',
          'image_front_small_url': 'https://img/x.jpg',
        },
      })!;
      expect(p.nombre, 'Leche entera');
      expect(p.presentacion, '1 L');
      expect(p.imageUrl, 'https://img/x.jpg');
    });

    test('arma el tamaño con cantidad y unidad', () {
      final p = ProductLookupService.parse({
        'status': 1,
        'product': {
          'product_name': 'Galletas',
          'product_quantity': 300,
          'product_quantity_unit': 'g',
        },
      })!;
      expect(p.presentacion, '300 g');
    });

    test('usa la marca si no hay nombre; null si no hay nada', () {
      expect(
        ProductLookupService.parse({
          'status': 1,
          'product': {'brands': 'Coca-Cola, The Coca-Cola Company'},
        })!.nombre,
        'Coca-Cola',
      );
      expect(ProductLookupService.parse({'status': 0}), isNull);
      expect(
        ProductLookupService.parse({'status': 1, 'product': {}}),
        isNull,
      );
    });
  });

  test('variantes UPC-A / EAN-13', () {
    expect(ProductLookupService.barcodeVariants('012345678905'),
        ['012345678905', '0012345678905']);
    expect(ProductLookupService.barcodeVariants('0012345678905'),
        ['0012345678905', '012345678905']);
    expect(ProductLookupService.barcodeVariants('ABC'), ['ABC']);
  });
}
