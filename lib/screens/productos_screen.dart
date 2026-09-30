import 'package:flutter/material.dart';

import '../models/categories.dart';
import '../models/product.dart';
import '../models/product_lots.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/lot_widgets.dart';
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

  /// Número de lote (L001...) de cada registro, sobre el inventario completo
  /// para que no cambie al filtrar (igual que en el Calendario).
  Map<String, String> _labels = const {};

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
        _labels = lotLabels(products);
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

  List<ProductGroup> get _groups {
    final query = _search.text.trim().toLowerCase();
    final lots = _all.where((p) {
      final matchesCat = _category == 'Todas' || p.categoria == _category;
      final matchesStat = _status == 'Todos' || p.status.label == _status;
      final matchesSearch = p.nombre.toLowerCase().contains(query);
      return matchesCat && matchesStat && matchesSearch;
    });

    final groups = groupProducts(lots);

    int byName(ProductGroup a, ProductGroup b) =>
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
          ? '¿Deseas eliminar el lote ${lotCode(p)} de "${p.nombre}" '
              '(vence ${p.fechaVencimiento})?'
          : '¿Deseas eliminar "${p.nombre}" del inventario?',
    );
    if (!ok) return;
    try {
      await _repo.deleteProduct(storeId, p.id);
      // Reprograma las alertas: se quitan las de este lote y se
      // conservan las de los demás lotes del mismo producto.
      await NotificationService.instance.syncStore(storeId);
      if (mounted) showMessage(context, 'Eliminado');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
  }

  /// "Editar producto": si hay un solo lote lo abre directo; si hay varios,
  /// pregunta cuál editar (cada lote es un registro independiente).
  Future<void> _editGroup(ProductGroup g) async {
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
                  '${_labels[g.lots[i].id] ?? lotLabel(i + 1)} · Vence ${g.lots[i].fechaVencimiento}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${g.lots[i].cantidad} unidades',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: StatusPill(g.lots[i].status, small: true),
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
  Future<void> _openLot(ProductGroup g, int index) async {
    final lot = g.lots[index];
    final action = await showLotDetailSheet(
      context,
      lot: lot,
      label: _labels[lot.id] ?? lotLabel(index + 1),
    );
    if (action == LotAction.edit) {
      await _edit(lot);
    } else if (action == LotAction.delete) {
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
                            labels: _labels,
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

/// Tarjeta expandible de un producto con la tabla de sus lotes.
class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.labels,
    required this.onOpenLot,
    required this.onEdit,
  });

  final ProductGroup group;
  final Map<String, String> labels;
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
                          CategoryTag(g.categoria),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusPill(g.status),
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
                                text: '${formatQty(g.totalQty)} un.',
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
            LotTableRow(
              label: labels[g.lots[i].id] ?? lotLabel(i + 1),
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
