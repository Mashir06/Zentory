import 'package:flutter/material.dart';

import '../models/categories.dart';
import '../models/product.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

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

  List<Product> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _all.where((p) {
      final matchesCat = _category == 'Todas' || p.categoria == _category;
      final matchesStat = _status == 'Todos' || p.status.label == _status;
      final matchesSearch = p.nombre.toLowerCase().contains(query);
      return matchesCat && matchesStat && matchesSearch;
    }).toList();
  }

  Future<void> _edit(Product p) async {
    await Navigator.of(context).pushNamed(
      Routes.addProduct,
      arguments: AddProductArgs(productId: p.id),
    );
    _load();
  }

  Future<void> _delete(Product p) async {
    final storeId = _storeId;
    if (storeId == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar producto',
      message: '¿Deseas eliminar "${p.nombre}" del inventario?',
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
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
    );
    if (value != null) onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
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
                        'Inventario de Productos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Gestiona y filtra tus artículos',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Filtrar por',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (btnCtx) => _FilterButton(
                                label: 'Categoría: $_category',
                                onTap: () => _pickFromMenu(
                                  anchorContext: btnCtx,
                                  options: ['Todas', ...kProductCategories],
                                  onSelected: (v) =>
                                      setState(() => _category = v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Builder(
                              builder: (btnCtx) => _FilterButton(
                                label: 'Estado: $_status',
                                onTap: () => _pickFromMenu(
                                  anchorContext: btnCtx,
                                  options: _statusOptions,
                                  onSelected: (v) =>
                                      setState(() => _status = v),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close,
                                      color: AppColors.textSecondary),
                                  onPressed: _search.clear,
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Todos los productos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            _all.isEmpty
                                ? 'Inventario vacío.'
                                : 'Sin coincidencias.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (final p in filtered)
                          ProductCard(
                            key: ValueKey(p.id),
                            product: p,
                            onEdit: () => _edit(p),
                            onDelete: () => _delete(p),
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
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      onTap: onTap,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
