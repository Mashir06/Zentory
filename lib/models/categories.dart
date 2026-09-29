/// Categorías disponibles para los productos (mismas que la app Kotlin).
const List<String> kProductCategories = [
  'Frutas y Verduras',
  'Carnes y Mariscos',
  'Refrigerados',
  'Congelados',
  'Panadería',
  'Abarrotes',
  'Bebidas',
  'Snacks y Dulces',
  'Limpieza del Hogar',
  'Higiene Personal',
  'Salud y Farmacia',
  'Bebés',
  'Mascotas',
  'Ferretería',
  'Hogar',
  'Electrónica',
  'Papelería y Oficina',
  'Ropa y Accesorios',
  'Licores y Cervezas',
];

/// Grupos que muestra la gráfica del inicio.
const List<String> kHomeCategoryGroups = [
  'Lácteos',
  'Bebidas',
  'Enlatados',
  'Panadería',
  'Otros',
];

/// Traduce una categoría de producto al grupo de la gráfica del inicio.
String homeGroupFor(String category) {
  switch (category) {
    case 'Refrigerados':
      return 'Lácteos';
    case 'Bebidas':
    case 'Licores y Cervezas':
      return 'Bebidas';
    case 'Abarrotes':
      return 'Enlatados';
    case 'Panadería':
      return 'Panadería';
    default:
      return 'Otros';
  }
}
