import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_lots.dart';
import '../routes.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/lot_widgets.dart';
import '../widgets/product_card.dart';

enum _ListMode { month, day, all }

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  final _repo = ZentoryRepository.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateUtilsZ.today();
  _ListMode _mode = _ListMode.month;
  List<Product> _products = [];

  /// Número de lote (L001...) de cada registro, igual que en Productos.
  Map<String, String> _labels = const {};
  bool _loading = true;

  static const _weekDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storeId = await _repo.resolveActiveStoreId();
      final products =
          storeId == null ? <Product>[] : await _repo.fetchProducts(storeId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _labels = lotLabels(products);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, 'No se pudieron cargar los productos: $e');
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _mode = _ListMode.month;
    });
  }

  List<Product> _productsOn(DateTime day) => _products
      .where((p) => p.expiryDate != null && DateUtilsZ.isSameDay(p.expiryDate!, day))
      .toList();

  /// Prioridad de color: rojo (vencido) > naranja (por vencer) > verde.
  Color? _dayColor(List<Product> onDay) {
    if (onDay.isEmpty) return null;
    if (onDay.any((p) => p.status == ProductStatus.expired)) {
      return AppColors.danger;
    }
    if (onDay.any((p) => p.status == ProductStatus.expiring)) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  List<Product> get _listed {
    switch (_mode) {
      case _ListMode.all:
        return _products;
      case _ListMode.day:
        return _productsOn(_selected);
      case _ListMode.month:
        return _products
            .where((p) =>
                p.expiryDate != null &&
                p.expiryDate!.year == _month.year &&
                p.expiryDate!.month == _month.month)
            .toList();
    }
  }

  String get _listTitle {
    switch (_mode) {
      case _ListMode.all:
        return 'Todos los lotes';
      case _ListMode.day:
        return 'Lotes que vencen el ${DateUtilsZ.dayOfMonth(_selected)}';
      case _ListMode.month:
        return 'Lotes de ${DateUtilsZ.monthYear(_month)}';
    }
  }

  /// Lotes agrupados por producto, empezando por el que vence antes.
  List<ProductGroup> _groupsOf(List<Product> lots) {
    final groups = groupProducts(lots);
    groups.sort((a, b) {
      final ea = a.nextExpiry;
      final eb = b.nextExpiry;
      final c = ea == null || eb == null
          ? (ea == null ? (eb == null ? 0 : 1) : -1)
          : ea.compareTo(eb);
      return c != 0
          ? c
          : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return groups;
  }

  String _summary(List<Product> lots) {
    final products = groupProducts(lots).length;
    return '${lots.length} ${lots.length == 1 ? 'lote' : 'lotes'} de '
        '$products ${products == 1 ? 'producto' : 'productos'}';
  }

  @override
  Widget build(BuildContext context) {
    final todayCount = _productsOn(DateUtilsZ.today()).length;
    final listed = _listed;

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
                      _monthSelector(),
                      const SizedBox(height: 12),
                      _calendarGrid(),
                      if (todayCount > 0) ...[
                        const SizedBox(height: 16),
                        ZCard(
                          color: AppColors.alertBrown,
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.white, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      todayCount == 1
                                          ? '1 lote vence hoy'
                                          : '$todayCount lotes vencen hoy',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Revisa tu inventario y evita pérdidas',
                                      style: TextStyle(
                                        color: Color(0xFFE0E0E0),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _listTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _mode = _ListMode.all),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      if (!_loading && listed.isNotEmpty)
                        Text(
                          _summary(listed),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (listed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            'No hay lotes que venzan en esta fecha',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        for (final g in _groupsOf(listed))
                          _CalendarLotsCard(
                            key: ValueKey('${_mode.name}-${g.key}'),
                            group: g,
                            labels: _labels,
                            onOpenLot: (lot) => showLotDetailSheet(
                              context,
                              lot: lot,
                              label: _labels[lot.id] ?? '',
                              allowActions: false,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ZentoryBottomNav(current: Routes.calendar),
    );
  }

  Widget _monthSelector() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Expanded(
          child: Text(
            DateUtilsZ.monthYear(_month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ],
    );
  }

  Widget _calendarGrid() {
    // La semana empieza el lunes. Se muestran 6 semanas (42 días).
    final first = DateTime(_month.year, _month.month, 1);
    final offset = first.weekday - DateTime.monday;
    final start = DateTime(first.year, first.month, first.day - offset);

    return ZCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _weekDays)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _dayCell(
                      DateTime(start.year, start.month, start.day + week * 7 + i),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day) {
    final isCurrentMonth = day.month == _month.month;
    final isSelected =
        _mode == _ListMode.day && DateUtilsZ.isSameDay(day, _selected);
    final isToday = DateUtilsZ.isSameDay(day, DateUtilsZ.today());
    final color = _dayColor(_productsOn(day));

    Color textColor = isCurrentMonth ? Colors.white : AppColors.textMuted;
    if (color != null) textColor = color;
    if (isSelected) textColor = Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _selected = day;
        _mode = _ListMode.day;
      }),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected || isToday)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : null,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.textSecondary)
                      : null,
                ),
              ),
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight:
                    color != null || isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (color != null)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un producto con la tabla de sus lotes del periodo elegido.
class _CalendarLotsCard extends StatelessWidget {
  const _CalendarLotsCard({
    super.key,
    required this.group,
    required this.labels,
    required this.onOpenLot,
  });

  final ProductGroup group;
  final Map<String, String> labels;
  final ValueChanged<Product> onOpenLot;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProductThumbnail(bytes: g.imageBytes, size: 48),
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
                        if (g.presentacion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          InfoTag(g.presentacion),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill(g.status),
                      const SizedBox(height: 6),
                      Text(
                        '${formatQty(g.totalQty)} un.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < g.lots.length; i++) ...[
                      if (i > 0)
                        const Divider(color: AppColors.border, height: 1),
                      LotTableRow(
                        label: labels[g.lots[i].id] ?? '',
                        lot: g.lots[i],
                        onTap: () => onOpenLot(g.lots[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
