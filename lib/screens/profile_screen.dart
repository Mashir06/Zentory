import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/store_dialogs.dart';

/// Perfil: tiendas del usuario, sucursales y personal.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ZentoryRepository.instance;

  String _userName = 'Cargando...';
  String _userRole = 'Usuario';
  String? _activeStoreId;
  List<Store> _stores = [];
  List<Store> _branches = [];
  List<StaffMember> _staff = [];
  bool _loading = true;

  bool get _isAdmin => _userRole == 'Administrador Principal';

  Store? get _activeStore {
    for (final s in _stores) {
      if (s.id == _activeStoreId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _repo.currentUser;
    if (user == null) return;
    try {
      final userDoc = await _repo.userRef(user.uid).get();
      final data = userDoc.data() ?? const <String, dynamic>{};
      final name = (data['nombre'] as String?) ??
          user.displayName ??
          user.email ??
          'Usuario';
      final currentId = data['tiendaId'] as String?;
      final ids = <String>{
        ...((data['tiendasIds'] as List?)?.whereType<String>() ?? const []),
        if (currentId != null) currentId,
      }.toList();

      final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
      if (ids.isNotEmpty) {
        final byId = await _repo.stores
            .where(FieldPath.documentId, whereIn: ids.take(10).toList())
            .get();
        docs.addAll(byId.docs);
      }
      // Compatibilidad con datos antiguos: tiendas creadas por nombre
      final byAdminName =
          await _repo.stores.where('adminNombre', isEqualTo: name).get();
      docs.addAll(byAdminName.docs);

      final seen = <String>{};
      final stores = <Store>[
        for (final d in docs)
          if (seen.add(d.id)) Store.fromDoc(d),
      ];

      String? activeId;
      if (stores.any((s) => s.id == currentId)) {
        activeId = currentId;
      } else if (stores.isNotEmpty) {
        activeId = stores.first.id;
      }

      var role = 'Usuario (Sin tiendas)';
      var staff = <StaffMember>[];
      var branches = <Store>[];
      if (activeId != null) {
        final activeName =
            stores.firstWhere((s) => s.id == activeId).nombre;
        final staffRes = await _repo.staff(activeId).get();
        staff = staffRes.docs.map(StaffMember.fromDoc).toList();
        StaffMember? me;
        for (final m in staff) {
          if (m.docId == name || m.uid == user.uid) {
            me = m;
            break;
          }
        }
        role = (me?.isAdmin ?? false)
            ? 'Administrador Principal'
            : 'Trabajador en $activeName';
        final branchRes = await _repo.branches(activeId).get();
        branches = branchRes.docs.map(Store.fromDoc).toList();
      }

      if (!mounted) return;
      setState(() {
        _userName = name;
        _stores = stores;
        _activeStoreId = activeId;
        _userRole = role;
        _staff = staff;
        _branches = branches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, 'No se pudo cargar el perfil: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _addStore() async {
    String? created;
    final ok = await showStoreFormDialog(
      context,
      title: 'Nueva Tienda',
      confirmLabel: 'Crear',
      onSubmit: (nombre, ubicacion) async {
        created = await _repo.createStore(nombre: nombre, ubicacion: ubicacion);
      },
    );
    if (!ok || !mounted) return;
    showMessage(context, "Tienda '$created' creada", long: true);
    _load();
  }

  Future<void> _joinStore() async {
    if (_userName == 'Cargando...') {
      showMessage(context, 'Espera a que cargue tu perfil');
      return;
    }
    final ok = await showJoinStoreDialog(
      context,
      onSubmit: (code) => _repo.joinStore(code),
    );
    if (!ok || !mounted) return;
    showMessage(context, 'Te has unido a la tienda');
    _load();
  }

  Future<void> _editStore(Store store, {bool isBranch = false}) async {
    final ok = await showStoreFormDialog(
      context,
      title: 'Editar Tienda',
      confirmLabel: 'Actualizar',
      initialNombre: store.nombre,
      initialUbicacion: store.ubicacion,
      onSubmit: (nombre, ubicacion) => _repo.updateStore(
        storeId: store.id,
        parentStoreId: isBranch ? _activeStoreId : null,
        nombre: nombre,
        ubicacion: ubicacion,
      ),
    );
    if (!ok || !mounted) return;
    showMessage(context, 'Tienda actualizada');
    _load();
  }

  Future<void> _deleteStore(Store store, {bool isBranch = false}) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Eliminar Tienda',
      message: isBranch
          ? "¿Estás seguro de que deseas eliminar la sucursal '${store.nombre}'?"
          : "¿Estás seguro de que deseas eliminar '${store.nombre}'? Se borrará "
              'toda la información, incluyendo personal, productos y sucursales.',
    );
    if (!confirmed || !mounted) return;
    try {
      if (isBranch) {
        await _repo.deleteBranch(_activeStoreId!, store.id);
        if (mounted) showMessage(context, 'Sucursal eliminada');
      } else {
        await _repo.deleteStore(store.id);
        if (mounted) {
          showMessage(context, 'Tienda y toda su información eliminada');
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
    _load();
  }

  Future<void> _selectStore(Store store) async {
    try {
      await _repo.setActiveStore(store.id);
      if (mounted) Routes.resetTo(context, Routes.home);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo cambiar de tienda: $e');
    }
  }

  Future<void> _removeStaff(StaffMember member) async {
    final storeId = _activeStoreId;
    if (storeId == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Eliminar Personal',
      message:
          "¿Estás seguro de que deseas eliminar a '${member.nombre}' de esta tienda?",
    );
    if (!confirmed) return;
    try {
      await _repo.removeStaffMember(storeId, member);
      if (mounted) showMessage(context, '${member.nombre} eliminado');
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo eliminar: $e');
    }
    _load();
  }

  void _copyCode(String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    showMessage(context, 'Código copiado: $code');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final active = _activeStore;
    final others = _stores.where((s) => s.id != _activeStoreId).toList();

    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              SimpleHeader(
                title: 'Mi Perfil',
                trailing: TextButton.icon(
                  onPressed: _joinStore,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Unirse a Tienda'),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            _profileCard(),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Mis Minisupers',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _addStore,
                                  child: const Text('+ Agregar'),
                                ),
                              ],
                            ),
                            if (active == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Aún no perteneces a ninguna tienda.',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            else
                              _StoreTile(
                                title: '${active.nombre} (Actual)',
                                subtitle: active.ubicacion,
                                code: active.codigoInvitacion,
                                color: AppColors.primaryDark,
                                subtitleColor: AppColors.primaryLight,
                                onCopy: _copyCode,
                                actions: [
                                  _TileAction('Editar', AppColors.primaryLight,
                                      () => _editStore(active)),
                                  _TileAction('Eliminar', const Color(0xFFFEF2F2),
                                      () => _deleteStore(active)),
                                ],
                              ),
                            if (_branches.isNotEmpty) ...[
                              _subHeader('Sucursales vinculadas'),
                              for (final b in _branches)
                                _StoreTile(
                                  title: b.nombre,
                                  subtitle: b.ubicacion,
                                  code: b.codigoInvitacion,
                                  onCopy: _copyCode,
                                  actions: [
                                    _TileAction('Editar', AppColors.primary,
                                        () => _editStore(b, isBranch: true)),
                                    _TileAction(
                                        'Eliminar',
                                        AppColors.dangerBright,
                                        () =>
                                            _deleteStore(b, isBranch: true)),
                                  ],
                                ),
                            ],
                            if (others.isNotEmpty) ...[
                              _subHeader('Otras de mis tiendas'),
                              for (final s in others)
                                _StoreTile(
                                  title: s.nombre,
                                  subtitle: 'Tocar para ver opciones',
                                  subtitleColor: AppColors.primary,
                                  actions: [
                                    _TileAction('Seleccionar',
                                        AppColors.primary, () => _selectStore(s)),
                                    _TileAction('Editar', AppColors.primary,
                                        () => _editStore(s)),
                                    _TileAction('Eliminar',
                                        AppColors.dangerBright, () => _deleteStore(s)),
                                  ],
                                ),
                            ],
                            const SizedBox(height: 24),
                            const Text(
                              'Administrar Personal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_staff.isEmpty)
                              const Text(
                                'No hay personal registrado.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            for (final m in _staff) _staffTile(m, active),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard() {
    return ZCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userRole,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );

  Widget _staffTile(StaffMember m, Store? active) {
    final canDelete = _isAdmin && m.nombre != _userName;
    return ZCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.border,
            child: Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${m.rol} - ${active?.nombre ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _removeStaff(m),
            ),
        ],
      ),
    );
  }
}

class _TileAction {
  const _TileAction(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Tarjeta de tienda que muestra sus acciones al tocarla.
class _StoreTile extends StatefulWidget {
  const _StoreTile({
    required this.title,
    required this.subtitle,
    required this.actions,
    this.code,
    this.onCopy,
    this.color = AppColors.surface,
    this.subtitleColor = AppColors.textSecondary,
  });

  final String title;
  final String subtitle;
  final String? code;
  final ValueChanged<String>? onCopy;
  final List<_TileAction> actions;
  final Color color;
  final Color subtitleColor;

  @override
  State<_StoreTile> createState() => _StoreTileState();
}

class _StoreTileState extends State<_StoreTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return ZCard(
      color: widget.color,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: TextStyle(color: widget.subtitleColor, fontSize: 13),
            ),
          ],
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => widget.onCopy?.call(code),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Código: $code',
                      style: TextStyle(
                        color: widget.subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy, size: 14, color: widget.subtitleColor),
                  ],
                ),
              ),
            ),
          ],
          if (_expanded)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  for (final a in widget.actions)
                    TextButton(
                      onPressed: a.onTap,
                      child: Text(a.label, style: TextStyle(color: a.color)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
