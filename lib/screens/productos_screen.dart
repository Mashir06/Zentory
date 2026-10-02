import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_lots.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/lot_widgets.dart';
import '../widgets/product_card.dart';
import '../l10n/strings.dart';

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

  /// Productos del catálogo (incluye los que aún no tienen lotes).
  List<CatalogItem> _catalog = [];
  String? _storeId;
  bool _loading = true;
  String _status = 'Todos';
  _SortOption _sort = _SortOption.expiry;

  /// Número de lote (L001...) de cada registro, sobre el inventario completo
  /// para que no cambie al filtrar (igual que en el Calendario).
  Map<String, String> _labels = {};

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
      final catalog = storeId == null
          ? <CatalogItem>[]
          : await _repo.fetchCatalog(storeId);
      if (!mounted) return;
      setState(() {
        _storeId = storeId;
        _all = products;
        _catalog = catalog;
        _labels = lotLabels(products);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, tr('No se pudieron cargar los productos: {0}', [e]));
    }
  }

  // ---------------------------------------------------------------------------
  // Filtros, agrupación y orden (solo presentación; no cambia los datos)
  // ---------------------------------------------------------------------------

  List<ProductGroup> get _groups {
    final query = _search.text.trim().toLowerCase();
    final lots = _all.where((p) {
      final matchesStat = _status == 'Todos' || p.status.label == _status;
      final matchesSearch = p.nombre.toLowerCase().contains(query);
      return matchesStat && matchesSearch;
    });
    // Los productos sin lotes solo se muestran cuando no se filtra por estado.
    final catalog = _status == 'Todos'
        ? _catalog.where((c) => c.nombre.toLowerCase().contains(query))
        : <CatalogItem>[];

    final groups = groupProducts(lots, catalog: catalog)
      ..removeWhere((g) => !g.hasLots && _status != 'Todos');

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

  int get _activeFilterCount => _status != 'Todos' ? 1 : 0;

  void _clearFilters() => setState(() => _status = 'Todos');

  // ---------------------------------------------------------------------------
  // Acciones (mismo funcionamiento que antes)
  // ---------------------------------------------------------------------------

  /// Editar un lote: solo fecha de vencimiento y cantidad.
  Future<void> _edit(Product p) async {
    await Navigator.of(context).pushNamed(
      Routes.lotForm,
      arguments: LotFormArgs(
        nombre: p.nombre,
        presentacion: p.presentacion,
        imagenBase64: p.imagenBase64,
        lotId: p.id,
        lotLabel: _labels[p.id],
      ),
    );
    _load();
  }

  Future<void> _delete(Product p, {required bool isLot}) async {
    final storeId = _storeId;
    if (storeId == null) return;
    final ok = await confirmDialog(
      context,
      title: tr('Eliminar lote'),
      message: isLot
          ? tr('¿Deseas eliminar el lote {0} de "{1}" (vence {2})?', [lotCode(p), p.nombre, p.fechaVencimiento])
          : tr('¿Deseas eliminar "{0}" del inventario?', [p.nombre]),
    );
    if (!ok) return;
    try {
      await _repo.deleteProduct(storeId, p.id);
      // Reprograma las alertas: se quitan las de este lote y se
      // conservan las de los demás lotes del mismo producto.
      await NotificationService.instance.syncStore(storeId);
      if (mounted) showMessage(context, tr('Eliminado'));
      _load();
    } catch (e) {
      if (mounted) showMessage(context, tr('No se pudo eliminar: {0}', [e]));
    }
  }

  /// Nuevo lote del producto: solo pide fecha de vencimiento y cantidad.
  Future<void> _addLot(ProductGroup g) async {
    await Navigator.of(context).pushNamed(
      Routes.lotForm,
      arguments: LotFormArgs(
        nombre: g.nombre,
        presentacion: g.presentacion,
        imagenBase64: g.imagenBase64,
      ),
    );
    _load();
  }

  /// Editar producto: nombre, foto y presentación (se aplica a sus lotes).
  Future<void> _editGroup(ProductGroup g) async {
    await Navigator.of(context).pushNamed(
      Routes.addProduct,
      arguments: ProductFormArgs(editName: g.nombre),
    );
    _load();
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
                  tr(o.label),
                  style: TextStyle(
                    color: o == _sort ? AppColors.primary : AppColors.textPrimary,
                    fontWeight:
                        o == _sort ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (o == _sort) ...[
                  SizedBox(width: 8),
                  Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
      ],
    );
    if (value != null) setState(() => _sort = value);
  }

  /// Hoja de filtros por estado (se aplica al tocarlo).
  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
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
            initialChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scroll) => ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Filtros'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      TextButton(
                        onPressed: () => update(() => _status = 'Todos'),
                        child: Text(tr('Limpiar')),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  tr('Estado'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _statusOptions)
                      _FilterChipZ(
                        label: tr(s),
                        color: _statusColorFor(s),
                        showDot: s != 'Todos',
                        selected: _status == s,
                        onTap: () => update(() => _status = s),
                      ),
                  ],
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('Ver resultados')),
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
              ZentoryHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      _titleBlock(),
                      SizedBox(height: 16),
                      _toolbar(),
                      if (_activeFilterCount > 0) ...[
                        SizedBox(height: 10),
                        _activeFilters(),
                      ],
                      SizedBox(height: 16),
                      if (_loading)
                        Padding(
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
                            onAddLot: () => _addLot(g),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ZentoryBottomNav(current: Routes.productos),
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
          child: Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Productos'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                tr('Gestiona tus productos, consulta sus lotes y mantén el control de tu inventario.'),
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
                style: TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('Buscar producto...'),
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('Borrar búsqueda'),
                          icon: Icon(Icons.close,
                              color: AppColors.textSecondary),
                          onPressed: _search.clear,
                        ),
                ),
              ),
            ),
            SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.tune,
              label: tr('Filtros'),
              compact: compact,
              badge: _activeFilterCount,
              onTap: _openFilters,
            ),
            SizedBox(width: 8),
            Builder(
              builder: (btnCtx) => _ToolbarButton(
                icon: Icons.swap_vert,
                label: tr('Ordenar'),
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
            label: tr(_status),
            color: _statusColorFor(_status),
            onRemove: () => setState(() => _status = 'Todos'),
          ),
        TextButton(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: Text(tr('Limpiar filtros')),
        ),
      ],
    );
  }

  Widget _emptyState() {
    final empty = _all.isEmpty && _catalog.isEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            empty ? Icons.inventory_2_outlined : Icons.search_off,
            color: AppColors.textMuted,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            empty ? tr('Inventario vacío.') : tr('Sin coincidencias.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
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
                color: active ? AppColors.primary : AppColors.textPrimary,
              ),
              if (!compact) ...[
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textSoft,
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
      padding: EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          InkWell(
            onTap: onRemove,
            customBorder: CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppColors.textPrimary),
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
    required this.onAddLot,
  });

  final ProductGroup group;
  final Map<String, String> labels;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onOpenLot;
  final VoidCallback onEdit;
  final VoidCallback onAddLot;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ProductThumbnail(bytes: g.imageBytes, size: 60),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.nombre.isEmpty ? tr('Sin nombre') : g.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (g.presentacion.isNotEmpty) ...[
                            SizedBox(height: 6),
                            InfoTag(g.presentacion),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusPill(g.status),
                        SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            text: tr('Total: '),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: tr('{0} un.', [formatQty(g.totalQty)]),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _lotsSection()
                  : SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotsSection() {
    final g = group;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              Icon(Icons.layers_outlined, color: AppColors.textPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                tr('Lotes ({0})', [g.lots.length]),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Divider(color: AppColors.border, height: 1),
          if (!g.hasLots)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                tr('Este producto aún no tiene lotes. Toca "Agregar lote" para registrar su fecha de vencimiento y cantidad.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          for (var i = 0; i < g.lots.length; i++) ...[
            LotTableRow(
              label: labels[g.lots[i].id] ?? lotLabel(i + 1),
              lot: g.lots[i],
              onTap: () => onOpenLot(i),
            ),
            Divider(color: AppColors.border, height: 1),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddLot,
                  icon: Icon(Icons.add, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tr('Agregar lote'), maxLines: 1, softWrap: false),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, 44),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child:
                        Text(tr('Editar producto'), maxLines: 1, softWrap: false),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(0, 44),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
