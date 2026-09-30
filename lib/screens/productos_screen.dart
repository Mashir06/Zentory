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

const _statusOptions = ['Todos', 'Buen estado', 'Por vencer', 'Vencido'];

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

Color _statusColorFor(String label) {
  switch (label) {
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

/// Cantidad numérica de un registro (el campo se guarda como texto).
num _qty(Product p) {
  final raw = p.cantidad.trim().replaceAll(',', '.');
  return int.tryParse(raw) ?? double.tryParse(raw) ?? 0;
}

String _formatQty(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// Texto relativo de vencimiento: "Vence en 3 días", "Venció hace 2 días"...
String _relativeExpiry(DateTime? expiry) {
  if (expiry == null) return 'Sin fecha de vencimiento';
  final d = DateUtilsZ.daysFromToday(expiry);
  if (d < 0) return d == -1 ? 'Venció ayer' : 'Venció hace ${-d} días';
  if (d == 0) return 'Vence hoy';
  if (d == 1) return 'Vence mañana';
  return 'Vence en $d días';
}

/// Número de lote para mostrar: L001, L002... (según orden de vencimiento).
String _lotLabel(int index) => 'L${index.toString().padLeft(3, '0')}';

/// Código del registro en Firestore, para distinguir lotes con precisión.
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

  String get categoria => lots.map((l) => l.categoria).toSet().join(', ');

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

  List<_ProductGroup> get _groups {
    final query = _search.text.trim().toLowerCase();
    final lots = _all.where((p) {
      final matchesCat = _category == 'Todas' || p.categoria == _category;
      final matchesStat = _status == 'Todos' || p.status.label == _status;
      final matchesSearch = p.nombre.toLowerCase().contains(query);
      return matchesCat && matchesStat && matchesSearch;
    });

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

  int get _activeFilterCount =>
      (_category != 'Todas' ? 1 : 0) + (_status != 'Todos' ? 1 : 0);

  void _clearFilters() => setState(() {
        _category = 'Todas';
        _status = 'Todos';
      });

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

  /// "Editar producto": si hay un solo lote lo abre directo; si hay varios,
  /// pregunta cuál editar (cada lote es un registro independiente).
  Future<void> _editGroup(_ProductGroup g) async {
    if (g.lots.length == 1) return _edit(g.main);
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '¿Qué lote deseas editar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var i = 0; i < g.lots.length; i++)
              ListTile(
                leading: const Icon(Icons.layers_outlined,
                    color: AppColors.textSecondary),
                title: Text(
                  '${_lotLabel(i + 1)} · Vence ${g.lots[i].fechaVencimiento}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${g.lots[i].cantidad} unidades',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: _StatusPill(g.lots[i].status, small: true),
                onTap: () => Navigator.pop(ctx, g.lots[i]),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await _edit(chosen);
  }

  /// Detalle de un lote con sus acciones (editar / eliminar).
  Future<void> _openLot(_ProductGroup g, int index) async {
    final lot = g.lots[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lote ${_lotLabel(index + 1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${lot.nombre} · ${_lotCode(lot)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(lot.status),
                ],
              ),
              const SizedBox(height: 16),
              _SheetRow('Fecha de vencimiento', lot.fechaVencimiento),
              _SheetRow('', _relativeExpiry(lot.expiryDate),
                  valueColor: lot.status.color),
              _SheetRow('Cantidad', '${lot.cantidad} unidades'),
              _SheetRow('Marca', lot.marca),
              _SheetRow('Presentación', lot.presentacion),
              _SheetRow('Fecha de registro', lot.fechaRegistro),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'delete'),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar lote'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'edit') {
      await _edit(lot);
    } else if (action == 'delete') {
      await _delete(lot, isLot: g.lots.length > 1);
    }
  }

  Future<void> _pickSort(BuildContext anchorContext) async {
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
    final value = await showMenu<_SortOption>(
      context: context,
      position: position,
      items: [
        for (final o in _SortOption.values)
          PopupMenuItem(
            value: o,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o.label,
                  style: TextStyle(
                    color: o == _sort ? AppColors.primary : Colors.white,
                    fontWeight:
                        o == _sort ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (o == _sort) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
      ],
    );
    if (value != null) setState(() => _sort = value);
  }

  /// Hoja de filtros: estado y categoría (se aplican al tocarlos).
  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            builder: (_, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filtros',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      TextButton(
                        onPressed: () => update(() {
                          _category = 'Todas';
                          _status = 'Todos';
                        }),
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _statusOptions)
                      _FilterChipZ(
                        label: s,
                        color: _statusColorFor(s),
                        showDot: s != 'Todos',
                        selected: _status == s,
                        onTap: () => update(() => _status = s),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Categoría',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ['Todas', ...kProductCategories])
                      _FilterChipZ(
                        label: c,
                        color: AppColors.primary,
                        selected: _category == c,
                        onTap: () => update(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Ver resultados'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final groups = _groups;

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
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      _titleBlock(),
                      const SizedBox(height: 16),
                      _toolbar(),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(height: 10),
                        _activeFilters(),
                      ],
                      const SizedBox(height: 16),
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
                            onOpenLot: (i) => _openLot(g, i),
                            onEdit: () => _editGroup(g),
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

  Widget _titleBlock() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Gestiona tus productos, consulta sus lotes y mantén el '
                'control de tu inventario.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Búsqueda + Filtros + Ordenar en una sola fila. En pantallas angostas
  /// los botones muestran solo el ícono para dejar espacio a la búsqueda.
  Widget _toolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.close,
                              color: AppColors.textSecondary),
                          onPressed: _search.clear,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.tune,
              label: 'Filtros',
              compact: compact,
              badge: _activeFilterCount,
              onTap: _openFilters,
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (btnCtx) => _ToolbarButton(
                icon: Icons.swap_vert,
                label: 'Ordenar',
                compact: compact,
                onTap: () => _pickSort(btnCtx),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _activeFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_status != 'Todos')
          _RemovableChip(
            label: _status,
            color: _statusColorFor(_status),
            onRemove: () => setState(() => _status = 'Todos'),
          ),
        if (_category != 'Todas')
          _RemovableChip(
            label: _category,
            color: AppColors.primary,
            onRemove: () => setState(() => _category = 'Todas'),
          ),
        TextButton(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
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

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final active = badge > 0;
    final button = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
          constraints: BoxConstraints(minWidth: compact ? 54 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.primary : Colors.white,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (active)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChipZ extends StatelessWidget {
  const _FilterChipZ({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : AppColors.background,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  final String label;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ],
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
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Etiqueta de categoría con ícono.
class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSoft, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila etiqueta/valor de la hoja de detalle de un lote.
class _SheetRow extends StatelessWidget {
  const _SheetRow(this.label, this.value, {this.valueColor = Colors.white});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight:
                  label.isEmpty ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta expandible de un producto con la tabla de sus lotes.
class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpenLot,
    required this.onEdit,
  });

  final _ProductGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onOpenLot;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ProductThumbnail(bytes: g.withImage.imageBytes, size: 60),
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
                          const SizedBox(height: 6),
                          _CategoryTag(g.categoria),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatusPill(g.status),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            text: 'Total: ',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: '${_formatQty(g.totalQty)} un.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
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
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _lotsSection()
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotsSection() {
    final g = group;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Lotes (${g.lots.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          for (var i = 0; i < g.lots.length; i++) ...[
            _LotRow(
              index: i + 1,
              lot: g.lots[i],
              onTap: () => onOpenLot(i),
            ),
            const Divider(color: AppColors.border, height: 1),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar producto'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de la tabla de lotes: Lote | F. vencimiento | Cantidad | Estado.
class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.index,
    required this.lot,
    required this.onTap,
  });

  final int index;
  final Product lot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _cell('Lote', Text(_lotLabel(index), style: _value)),
            ),
            Expanded(
              flex: 3,
              child: _cell(
                'F. vencimiento',
                Text(
                  lot.expiryDate == null ? 'Sin fecha' : lot.fechaVencimiento,
                  style: _value,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _cell('Cantidad', Text(lot.cantidad, style: _value)),
            ),
            Expanded(
              flex: 3,
              child: _cell(
                'Estado',
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(lot.status, small: true),
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  static const _value = TextStyle(color: Colors.white, fontSize: 13);

  Widget _cell(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}
