import 'package:flutter/material.dart';

import '../models/categories.dart';
import '../models/product.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

/// Opciones de ordenamiento del listado.
enum _SortOption {
  expiry('Próximo a vencer'),
  name('Nombre (A–Z)'),
  quantity('Mayor cantidad');

  const _SortOption(this.label);
  final String label;
}

/// Prioridad de un estado para decidir el estado general de un producto
/// (el lote "peor" manda): vencido > por vencer > sin fecha > buen estado.
int _statusRank(ProductStatus s) {
  switch (s) {
    case ProductStatus.expired:
      return 3;
    case ProductStatus.expiring:
      return 2;
    case ProductStatus.noDate:
      return 1;
    case ProductStatus.good:
      return 0;
  }
}

/// Cantidad numérica de un registro (el campo se guarda como texto).
num _qty(Product p) {
  final raw = p.cantidad.trim().replaceAll(',', '.');
  return int.tryParse(raw) ?? double.tryParse(raw) ?? 0;
}

String _formatQty(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

/// Texto relativo de vencimiento: "Vence en 3 días", "Venció hace 2 días"...
String _relativeExpiry(DateTime? expiry) {
  if (expiry == null) return 'Sin fecha de vencimiento';
  final d = DateUtilsZ.daysFromToday(expiry);
  if (d < 0) return d == -1 ? 'Venció ayer' : 'Venció hace ${-d} días';
  if (d == 0) return 'Vence hoy';
  if (d == 1) return 'Vence mañana';
  return 'Vence en $d días';
}

/// Identificador corto y legible de un lote a partir del ID del documento.
String _lotCode(Product p) {
  final id = p.id;
  return '#${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';
}

/// Un producto con todos sus lotes (registros con el mismo nombre).
class _ProductGroup {
  _ProductGroup(this.key, List<Product> lots)
      : lots = _sortLots(lots),
        status = lots
            .map((l) => l.status)
            .reduce((a, b) => _statusRank(a) >= _statusRank(b) ? a : b),
        totalQty = lots.fold<num>(0, (sum, l) => sum + _qty(l));

  final String key;
  final List<Product> lots;
  final ProductStatus status;
  final num totalQty;

  Product get main => lots.first;
  String get nombre => main.nombre;

  /// Primer lote con foto, para la miniatura del producto.
  Product get withImage =>
      lots.firstWhere((l) => l.imageBytes != null, orElse: () => main);

  /// Fecha de vencimiento más próxima entre los lotes.
  DateTime? get nextExpiry => main.expiryDate;

  /// Categorías y marcas distintas (normalmente una sola).
  String get categoria => lots.map((l) => l.categoria).toSet().join(', ');
  String get marca {
    final marcas = lots
        .map((l) => l.marca)
        .where((m) => m.trim().isNotEmpty && m != 'N/A')
        .toSet();
    return marcas.isEmpty ? 'N/A' : marcas.join(', ');
  }

  String get presentacion {
    final values = lots
        .map((l) => l.presentacion)
        .where((m) => m.trim().isNotEmpty && m != 'N/A')
        .toSet();
    return values.isEmpty ? 'N/A' : values.join(', ');
  }

  /// Lotes ordenados por vencimiento (los que vencen antes primero).
  static List<Product> _sortLots(List<Product> lots) {
    final sorted = [...lots];
    sorted.sort((a, b) {
      final ea = a.expiryDate;
      final eb = b.expiryDate;
      if (ea == null && eb == null) return 0;
      if (ea == null) return 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });
    return sorted;
  }
}

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final _repo = ZentoryRepository.instance;
  final _search = TextEditingController();

  List<Product> _all = [];
  String? _storeId;
  bool _loading = true;
  String _category = 'Todas';
  String _status = 'Todos';
  _SortOption _sort = _SortOption.expiry;

  /// Productos expandidos (se conserva al recargar tras editar o eliminar).
  final Set<String> _expanded = {};

  static const _statusOptions = ['Todos', 'Buen estado', 'Por vencer', 'Vencido'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final storeId = _storeId ?? await _repo.resolveActiveStoreId();
      final products =
          storeId == null ? <Product>[] : await _repo.fetchProducts(storeId);
      if (!mounted) return;
      setState(() {
        _storeId = storeId;
        _all = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, 'No se pudieron cargar los productos: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Filtros, agrupación y orden (solo presentación; no cambia los datos)
  // ---------------------------------------------------------------------------

  /// Registros que cumplen la búsqueda y la categoría (sin filtro de estado).
  List<Product> get _searchScope {
    final query = _search.text.trim().toLowerCase();
    return _all.where((p) {
      final matchesCat = _category == 'Todas' || p.categoria == _category;
      final matchesSearch = p.nombre.toLowerCase().contains(query);
      return matchesCat && matchesSearch;
    }).toList();
  }

  /// Cantidad de lotes por estado, para los chips de filtro.
  Map<String, int> _statusCounts(List<Product> scope) {
    final counts = {for (final s in _statusOptions) s: 0};
    counts['Todos'] = scope.length;
    for (final p in scope) {
      final label = p.status.label;
      if (counts.containsKey(label)) counts[label] = counts[label]! + 1;
    }
    return counts;
  }

  List<_ProductGroup> _groups(List<Product> scope) {
    final lots = _status == 'Todos'
        ? scope
        : scope.where((p) => p.status.label == _status).toList();

    final map = <String, List<Product>>{};
    for (final p in lots) {
      final name = p.nombre.trim().toLowerCase();
      final key = name.isEmpty ? 'id:${p.id}' : name;
      map.putIfAbsent(key, () => []).add(p);
    }
    final groups = [
      for (final e in map.entries) _ProductGroup(e.key, e.value),
    ];

    int byName(_ProductGroup a, _ProductGroup b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());

    switch (_sort) {
      case _SortOption.name:
        groups.sort(byName);
      case _SortOption.quantity:
        groups.sort((a, b) {
          final c = b.totalQty.compareTo(a.totalQty);
          return c != 0 ? c : byName(a, b);
        });
      case _SortOption.expiry:
        groups.sort((a, b) {
          final ea = a.nextExpiry;
          final eb = b.nextExpiry;
          if (ea == null && eb == null) return byName(a, b);
          if (ea == null) return 1;
          if (eb == null) return -1;
          final c = ea.compareTo(eb);
          return c != 0 ? c : byName(a, b);
        });
    }
    return groups;
  }

  bool get _hasActiveFilters =>
      _category != 'Todas' || _status != 'Todos' || _search.text.isNotEmpty;

  void _clearFilters() {
    _search.clear();
    setState(() {
      _category = 'Todas';
      _status = 'Todos';
    });
  }

  // ---------------------------------------------------------------------------
  // Acciones (mismo funcionamiento que antes)
  // ---------------------------------------------------------------------------

  Future<void> _edit(Product p) async {
    await Navigator.of(context).pushNamed(
      Routes.addProduct,
      arguments: AddProductArgs(productId: p.id),
    );
    _load();
  }

  Future<void> _delete(Product p, {required bool isLot}) async {
    final storeId = _storeId;
    if (storeId == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar producto',
      message: isLot
          ? '¿Deseas eliminar el lote ${_lotCode(p)} de "${p.nombre}" '
              '(vence ${p.fechaVencimiento})?'
          : '¿Deseas eliminar "${p.nombre}" del inventario?',
    );
    if (!ok) return;
    try {
      await _repo.deleteProduct(storeId, p.id);
      await NotificationService.instance.cancelProductNotifications(p.nombre);
      if (mounted) showMessage(context, 'Eliminado');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
  }

  Future<void> _pickFromMenu({
    required BuildContext anchorContext,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o,
                  style: TextStyle(
                    color: o == selected ? AppColors.primary : Colors.white,
                    fontWeight:
                        o == selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (o == selected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
      ],
    );
    if (value != null) onSelected(value);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scope = _searchScope;
    final counts = _statusCounts(scope);
    final groups = _groups(scope);
    final lotCount = groups.fold<int>(0, (sum, g) => sum + g.lots.length);

    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const ZentoryHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const Text(
                        'Productos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Gestiona tus artículos, lotes y vencimientos',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      _searchField(),
                      const SizedBox(height: 10),
                      _filterRow(),
                      const SizedBox(height: 10),
                      _statusChips(counts),
                      const SizedBox(height: 20),
                      _listHeader(groups.length, lotCount),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (groups.isEmpty)
                        _emptyState()
                      else
                        for (final g in groups)
                          _ProductGroupCard(
                            key: ValueKey(g.key),
                            group: g,
                            expanded: _expanded.contains(g.key),
                            onToggle: () => setState(() {
                              if (!_expanded.remove(g.key)) {
                                _expanded.add(g.key);
                              }
                            }),
                            onEdit: _edit,
                            onDelete: (p) =>
                                _delete(p, isLot: g.lots.length > 1),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ZentoryBottomNav(current: Routes.productos),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre...',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: _search.clear,
              ),
      ),
    );
  }

  Widget _filterRow() {
    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (btnCtx) => _FilterButton(
              icon: Icons.category_outlined,
              label: _category == 'Todas' ? 'Categoría' : _category,
              active: _category != 'Todas',
              onTap: () => _pickFromMenu(
                anchorContext: btnCtx,
                options: ['Todas', ...kProductCategories],
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Builder(
            builder: (btnCtx) => _FilterButton(
              icon: Icons.swap_vert,
              label: _sort.label,
              onTap: () => _pickFromMenu(
                anchorContext: btnCtx,
                options: [for (final s in _SortOption.values) s.label],
                selected: _sort.label,
                onSelected: (v) => setState(() => _sort =
                    _SortOption.values.firstWhere((s) => s.label == v)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChips(Map<String, int> counts) {
    Color colorFor(String s) {
      switch (s) {
        case 'Buen estado':
          return ProductStatus.good.color;
        case 'Por vencer':
          return ProductStatus.expiring.color;
        case 'Vencido':
          return ProductStatus.expired.color;
        default:
          return AppColors.primary;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _statusOptions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StatusChip(
                label: s,
                count: counts[s] ?? 0,
                color: colorFor(s),
                showDot: s != 'Todos',
                selected: _status == s,
                onTap: () => setState(() => _status = s),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listHeader(int productCount, int lotCount) {
    final summary = _loading
        ? ''
        : '$productCount ${productCount == 1 ? 'producto' : 'productos'} · '
            '$lotCount ${lotCount == 1 ? 'lote' : 'lotes'}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasActiveFilters ? 'Resultados' : 'Todos los productos',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (_hasActiveFilters)
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Limpiar filtros'),
          ),
      ],
    );
  }

  Widget _emptyState() {
    final empty = _all.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            empty ? Icons.inventory_2_outlined : Icons.search_off,
            color: AppColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            empty ? 'Inventario vacío.' : 'Sin coincidencias.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Componentes de la pantalla
// -----------------------------------------------------------------------------

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      onTap: onTap,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppColors.primary : Colors.white,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    this.showDot = true,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? color : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSoft,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Píldora de estado con los colores de Zentory.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status, {this.small = false});
  final ProductStatus status;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dato breve con ícono (cantidad, lotes...).
class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
        ),
      ],
    );
  }
}

/// Tarjeta expandible de un producto con sus lotes.
class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final _ProductGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final lotsLabel = '${g.lots.length} ${g.lots.length == 1 ? 'lote' : 'lotes'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: g.status.color, width: 4)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductThumbnail(bytes: g.withImage.imageBytes),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.nombre.isEmpty ? 'Sin nombre' : g.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  g.categoria,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _InfoTag(
                                      icon: Icons.inventory_2_outlined,
                                      text: '${_formatQty(g.totalQty)} unidades',
                                    ),
                                    _InfoTag(
                                      icon: Icons.layers_outlined,
                                      text: lotsLabel,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusPill(g.status),
                              const SizedBox(height: 6),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined,
                                size: 16, color: g.main.status.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                g.nextExpiry == null
                                    ? 'Sin fecha de vencimiento'
                                    : 'Próximo vencimiento: ${g.main.fechaVencimiento}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (g.nextExpiry != null)
                              Text(
                                _relativeExpiry(g.nextExpiry),
                                style: TextStyle(
                                  color: g.main.status.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: expanded
                    ? _details(context)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context) {
    final g = group;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _detail('Marca', g.marca)),
              const SizedBox(width: 12),
              Expanded(child: _detail('Presentación', g.presentacion)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Lotes (${g.lots.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < g.lots.length; i++)
            _LotTile(
              index: i + 1,
              lot: g.lots[i],
              onEdit: () => onEdit(g.lots[i]),
              onDelete: () => onDelete(g.lots[i]),
            ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

/// Un lote (registro) dentro de la tarjeta expandida.
class _LotTile extends StatelessWidget {
  const _LotTile({
    required this.index,
    required this.lot,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final Product lot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = lot.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Lote $index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _lotCode(lot),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lot.expiryDate == null
                            ? 'Sin fecha de vencimiento'
                            : 'Vence: ${lot.fechaVencimiento}',
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 12,
                        ),
                      ),
                      if (lot.expiryDate != null)
                        Text(
                          _relativeExpiry(lot.expiryDate),
                          style: TextStyle(
                            color: status.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Registrado: ${lot.fechaRegistro}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lot.cantidad,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'unidades',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(status, small: true),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
