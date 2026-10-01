import 'package:flutter/material.dart';

import '../models/product.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/donut_chart.dart';
import '../l10n/strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeStats {
  int good = 0;
  int expiring = 0;
  int expired = 0;
  int tomorrow = 0;
  int get total => good + expiring + expired;

  /// Lotes por estado, para la gráfica de dona.
  Map<String, int> get byStatus => {
        'Buen estado': good,
        'Por vencer': expiring,
        'Vencidos': expired,
      };

  static _HomeStats from(List<Product> products) {
    final s = _HomeStats();
    for (final p in products) {
      final expiry = p.expiryDate;
      if (expiry == null) {
        s.good++; // Igual que la app Kotlin: sin fecha cuenta como buen estado
      } else {
        final diff = DateUtilsZ.daysFromToday(expiry);
        if (diff <= 0) {
          s.expired++;
        } else if (diff <= 7) {
          if (diff == 1) s.tomorrow++;
          s.expiring++;
        } else {
          s.good++;
        }
      }
    }
    return s;
  }
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final _repo = ZentoryRepository.instance;

  String _userName = '(Usuario)';
  String? _storeId;
  bool _loading = true;
  _HomeStats _stats = _HomeStats();

  static const _statusColors = {
    'Buen estado': AppColors.primary,
    'Por vencer': AppColors.amber,
    'Vencidos': AppColors.dangerBright,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Se recargan los datos cada vez que el usuario vuelve al inicio.
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    try {
      final name = await _repo.currentUserName();
      final storeId = await _repo.resolveActiveStoreId();
      if (storeId == null) {
        // Ya no pertenece a ninguna tienda (la eliminaron o lo quitaron del
        // personal): debe crear o unirse a una para seguir.
        NotificationService.instance.clearAll();
        if (mounted) Routes.resetTo(context, Routes.storeSelection);
        return;
      }
      final products = await _repo.fetchProducts(storeId);
      // Recrea las alertas de vencimiento cada vez que se abre la app o se
      // vuelve al inicio (algunos sistemas borran las alarmas al cerrar la app).
      NotificationService.instance.syncProducts(products);
      if (!mounted) return;
      setState(() {
        _userName = name;
        _storeId = storeId;
        _stats = _HomeStats.from(products);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, tr('No se pudieron cargar los datos: {0}', [e]));
    }
  }

  Future<void> _addProduct() async {
    if (_storeId == null) {
      showMessage(
        context,
        tr('Debes unirte a una tienda antes de poder agregar un producto'),
      );
      return;
    }
    await Navigator.of(context).pushNamed(Routes.addProduct);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ZentoryHeader(
                trailing: IconButton(
                  tooltip: tr('Configuración'),
                  icon: Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.settings),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(
                        tr('¡Hola, {0}! 👋', [_userName]),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        tr('Aquí tienes el resumen de tu minisúper'),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 16),
                      if (_loading)
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_storeId == null)
                        _noStoreCard()
                      else ...[
                        _statsGrid(),
                        if (_stats.tomorrow > 0) ...[
                          SizedBox(height: 16),
                          _tomorrowAlert(),
                        ],
                        SizedBox(height: 20),
                        _statusCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onColor,
        tooltip: tr('Agregar producto'),
        child: Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: ZentoryBottomNav(current: Routes.home),
    );
  }

  Widget _statsGrid() {
    final cards = [
      _StatCard(
        icon: Icons.check_circle_outline,
        color: AppColors.primary,
        value: _stats.good,
        label: tr('En buen estado'),
      ),
      _StatCard(
        icon: Icons.schedule,
        color: AppColors.amber,
        value: _stats.expiring,
        label: tr('Por vencer (7 días)'),
      ),
      _StatCard(
        icon: Icons.warning_amber_rounded,
        color: AppColors.dangerBright,
        value: _stats.expired,
        label: tr('Vencidos'),
      ),
      _StatCard(
        icon: Icons.inventory_2_outlined,
        color: AppColors.info,
        value: _stats.total,
        label: tr('Total de productos'),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: cards,
    );
  }

  Widget _tomorrowAlert() {
    return ZCard(
      color: AppColors.alertBrown,
      onTap: () => Routes.goToTab(context, Routes.productos),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.onColor, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('{0} productos vencen mañana', [_stats.tomorrow]),
                  style: TextStyle(
                    color: AppColors.onColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  tr('Revisa tu inventario y evita pérdidas'),
                  style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.onColor),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Inventario por estado'),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        ZCard(
          child: Row(
            children: [
              DonutChart(
                values: _stats.byStatus,
                colors: _statusColors,
                size: 130,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final group in _statusColors.keys)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _statusColors[group],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr(group),
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              '${_stats.byStatus[group] ?? 0}',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noStoreCard() {
    return ZCard(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined,
              color: AppColors.primary, size: 48),
          SizedBox(height: 12),
          Text(
            tr('¡Aún no tienes una tienda!'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            tr('Para empezar a gestionar tus productos, necesitas unirte a una tienda o crear la tuya desde tu perfil.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.profile),
            child: Text(tr('Configurar Tienda')),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      color: AppColors.surfaceAlt,
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              Spacer(),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              Text(
                tr('Productos'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
