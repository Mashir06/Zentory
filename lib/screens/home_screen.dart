import 'package:flutter/material.dart';

import '../models/product.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/donut_chart.dart';

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
      showMessage(context, 'No se pudieron cargar los datos: $e');
    }
  }

  Future<void> _addProduct() async {
    if (_storeId == null) {
      showMessage(
        context,
        'Debes unirte a una tienda antes de poder agregar un producto',
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
                  tooltip: 'Configuración',
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.settings),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(
                        '¡Hola, $_userName! 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Aquí tienes el resumen de tu minisúper',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_storeId == null)
                        _noStoreCard()
                      else ...[
                        _statsGrid(),
                        if (_stats.tomorrow > 0) ...[
                          const SizedBox(height: 16),
                          _tomorrowAlert(),
                        ],
                        const SizedBox(height: 20),
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
        foregroundColor: Colors.white,
        tooltip: 'Agregar producto',
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: const ZentoryBottomNav(current: Routes.home),
    );
  }

  Widget _statsGrid() {
    final cards = [
      _StatCard(
        icon: Icons.check_circle_outline,
        color: AppColors.primary,
        value: _stats.good,
        label: 'En buen estado',
      ),
      _StatCard(
        icon: Icons.schedule,
        color: AppColors.amber,
        value: _stats.expiring,
        label: 'Por vencer (7 días)',
      ),
      _StatCard(
        icon: Icons.warning_amber_rounded,
        color: AppColors.dangerBright,
        value: _stats.expired,
        label: 'Vencidos',
      ),
      _StatCard(
        icon: Icons.inventory_2_outlined,
        color: AppColors.info,
        value: _stats.total,
        label: 'Total de productos',
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_stats.tomorrow} productos vencen mañana',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Revisa tu inventario y evita pérdidas',
                  style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inventario por estado',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ZCard(
          child: Row(
            children: [
              DonutChart(
                values: _stats.byStatus,
                colors: _statusColors,
                size: 130,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final group in _statusColors.keys)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              '${_stats.byStatus[group] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined,
              color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          const Text(
            '¡Aún no tienes una tienda!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para empezar a gestionar tus productos, necesitas unirte a una '
            'tienda o crear la tuya desde tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.profile),
            child: const Text('Configurar Tienda'),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Text(
                'Productos',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
