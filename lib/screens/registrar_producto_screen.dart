import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../models/product_lots.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/product_lookup_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/image_utils.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/notification_setup_sheet.dart';
import '../widgets/product_card.dart';
import '../l10n/strings.dart';

enum _PhotoChoice { camera, gallery, remove }

// =============================================================================
// Formulario de PRODUCTO: nombre, foto y presentación (tamaño)
// =============================================================================

/// Crear o editar un producto. Los datos de vencimiento y cantidad van en
/// cada lote ([LotFormScreen]).
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.args = const ProductFormArgs()});

  final ProductFormArgs args;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _repo = ZentoryRepository.instance;
  final _picker = ImagePicker();

  late final _nombre = TextEditingController(text: widget.args.qrNombre ?? '');
  late final _presentacion =
      TextEditingController(text: widget.args.qrPresentacion ?? '');
  final _codigo = TextEditingController();

  String? _imagenBase64;
  Uint8List? _imageBytes;

  String? _storeId;

  /// Productos ya registrados (para no duplicarlos).
  List<ProductGroup> _existing = [];

  /// Producto existente con el mismo nombre que se está escribiendo.
  ProductGroup? _match;

  bool _loading = true;
  bool _saving = false;
  bool _scanning = false;

  bool get _isEditing => widget.args.editName != null;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(_checkExisting);
    _init();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _presentacion.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final storeId = await _repo.resolveActiveStoreId();
      if (!mounted) return;
      if (storeId == null) {
        showMessage(context, tr('No tienes una tienda vinculada'));
        Navigator.of(context).maybePop();
        return;
      }
      _storeId = storeId;
      final lots = await _repo.fetchProducts(storeId);
      final catalog = await _repo.fetchCatalog(storeId);
      final groups = groupProducts(lots, catalog: catalog)
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

      final editName = widget.args.editName;
      if (editName != null) {
        final key = editName.trim().toLowerCase();
        for (final g in groups) {
          if (g.key == key) {
            _nombre.text = g.nombre;
            _presentacion.text = g.presentacion;
            _codigo.text = g.codigoBarras ?? '';
            _setImage(g.imagenBase64);
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _existing = groups;
        _loading = false;
      });
      _checkExisting();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, tr('Error al cargar: {0}', [e]));
    }
  }

  void _setImage(String? base64) {
    _imagenBase64 = (base64 == null || base64.isEmpty) ? null : base64;
    _imageBytes = ImageUtils.decode(_imagenBase64);
  }

  /// Avisa si ya existe un producto con el nombre escrito.
  void _checkExisting() {
    final key = _nombre.text.trim().toLowerCase();
    ProductGroup? match;
    final original = widget.args.editName?.trim().toLowerCase();
    if (key.isNotEmpty && key != original) {
      for (final g in _existing) {
        if (g.key == key) {
          match = g;
          break;
        }
      }
    }
    if (match != _match) setState(() => _match = match);
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: Text(tr('Cámara'), style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title:
                  Text(tr('Galería'), style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.gallery),
            ),
            if (_imageBytes != null)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text(tr('Quitar foto'),
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, _PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == _PhotoChoice.remove) {
      setState(() => _setImage(null));
      return;
    }
    final source = choice == _PhotoChoice.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      // JPEG de 400 px de ancho al 70 % de calidad (igual que antes).
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 400,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imagenBase64 = ImageUtils.encode(bytes);
      });
    } catch (e) {
      if (mounted) showMessage(context, tr('No se pudo obtener la foto: {0}', [e]));
    }
  }

  /// Escanea el código de barras. Si ya pertenece a un producto de la
  /// tienda, se pasa directo a crearle un lote; si no, se guarda en el
  /// formulario y se intenta rellenar nombre y tamaño con OpenFoodFacts.
  Future<void> _scan() async {
    final code = await Navigator.of(context).pushNamed<String>(Routes.scan);
    final storeId = _storeId;
    if (code == null || code.isEmpty || storeId == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final existing = await _repo.findProductByBarcode(storeId, code);
      if (!mounted) return;
      final original = widget.args.editName?.trim().toLowerCase();
      if (existing != null &&
          existing.nombre.trim().toLowerCase() != original) {
        if (_isEditing) {
          showMessage(context,
              tr('Ese código de barras ya pertenece a "{0}"', [existing.nombre]));
          return;
        }
        showMessage(context,
            tr('"{0}" ya está registrado. Agrega un lote nuevo.', [existing.nombre]));
        Navigator.of(context).pushReplacementNamed(
          Routes.lotForm,
          arguments: LotFormArgs(
            nombre: existing.nombre,
            presentacion: existing.presentacion,
            imagenBase64: existing.imagenBase64,
          ),
        );
        return;
      }
      _codigo.text = code;
      // Solo se rellenan los campos vacíos (no se pisa lo ya escrito).
      if (_nombre.text.trim().isEmpty || _presentacion.text.trim().isEmpty) {
        ScannedProduct? found;
        try {
          found = await ProductLookupService.lookup(code);
        } catch (_) {
          found = null;
        }
        if (!mounted) return;
        if (found == null) {
          showMessage(
            context,
            tr('Código guardado. No se encontró información del producto; escribe el nombre y el tamaño.'),
            long: true,
          );
        } else {
          if (_nombre.text.trim().isEmpty) _nombre.text = found.nombre;
          if (_presentacion.text.trim().isEmpty) {
            _presentacion.text = found.presentacion;
          }
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, tr('Error al cargar: {0}', [e]));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Abre el formulario de lote para un producto ya registrado.
  void _addLotTo(ProductGroup g) {
    Navigator.of(context).pushReplacementNamed(
      Routes.lotForm,
      arguments: LotFormArgs(
        nombre: g.nombre,
        presentacion: g.presentacion,
        imagenBase64: g.imagenBase64,
      ),
    );
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final presentacion = _presentacion.text.trim();
    final storeId = _storeId;
    if (nombre.isEmpty) {
      showMessage(context, tr('Escribe el nombre del producto'));
      return;
    }
    if (storeId == null) return;
    if (_match != null) {
      showMessage(context, tr('Ya existe un producto con ese nombre'));
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _repo.updateProduct(
          storeId: storeId,
          originalName: widget.args.editName!,
          nombre: nombre,
          presentacion: presentacion,
          imagenBase64: _imagenBase64,
          codigoBarras: _codigo.text.trim(),
        );
        // El nombre aparece en las alertas: se reprograman.
        await NotificationService.instance.syncStore(storeId);
        if (!mounted) return;
        showMessage(context, tr('Producto actualizado'));
        Navigator.of(context).pop(true);
      } else {
        await _repo.createProduct(
          storeId: storeId,
          nombre: nombre,
          presentacion: presentacion,
          imagenBase64: _imagenBase64,
          codigoBarras: _codigo.text.trim(),
        );
        if (!mounted) return;
        showMessage(context, tr('Producto creado. Ahora agrega su primer lote.'));
        // Un producto se usa con lotes: se pasa directo a crear el primero.
        Navigator.of(context).pushReplacementNamed(
          Routes.lotForm,
          arguments: LotFormArgs(
            nombre: nombre,
            presentacion: presentacion,
            imagenBase64: _imagenBase64,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(
        context,
        e is ZentoryException ? e.message : tr('No se pudo guardar: {0}', [e]),
      );
    }
  }

  Future<void> _delete() async {
    final storeId = _storeId;
    final name = widget.args.editName;
    if (storeId == null || name == null) return;
    final ok = await confirmDialog(
      context,
      title: tr('Eliminar producto'),
      message: tr('¿Deseas eliminar "{0}" y todos sus lotes del inventario?', [name]),
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await _repo.deleteProductAndLots(storeId, name);
      await NotificationService.instance.syncStore(storeId);
      if (!mounted) return;
      showMessage(context, tr('Producto eliminado'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, tr('No se pudo eliminar: {0}', [e]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _form(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final others = _isEditing ? <ProductGroup>[] : _existing;
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _FormTitle(
          icon: _isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
          title: _isEditing ? tr('Editar producto') : tr('Agregar producto'),
          subtitle: _isEditing
              ? tr('Los cambios se aplican a todos sus lotes')
              : tr('Registra el producto; luego le agregas sus lotes'),
        ),
        SizedBox(height: 16),
        _scanButton(),
        SizedBox(height: 20),
        Center(child: _photoPicker()),
        SizedBox(height: 16),
        LabeledField(
          label: tr('Nombre del producto *'),
          controller: _nombre,
          hint: tr('Ej. Leche Chiricana'),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_match != null) ...[
          SizedBox(height: 8),
          ZCard(
            color: AppColors.surfaceAlt,
            padding: EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('"{0}" ya está registrado.', [_match!.nombre]),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
                if (!_isEditing)
                  TextButton(
                    onPressed: () => _addLotTo(_match!),
                    child: Text(tr('Agregar lote')),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: 14),
        LabeledField(
          label: tr('Presentación (tamaño)'),
          controller: _presentacion,
          hint: tr('Ej. 946 ml, 1 litro, 500 g'),
        ),
        SizedBox(height: 14),
        LabeledField(
          label: tr('Código de barras'),
          controller: _codigo,
          hint: tr('Opcional: escanéalo o escríbelo'),
          prefixIcon: Icons.qr_code_2,
          suffix: IconButton(
            tooltip: tr('Escanear código'),
            onPressed: _scanning ? null : _scan,
            icon: Icon(Icons.qr_code_scanner, color: AppColors.primary),
          ),
        ),
        SizedBox(height: 24),
        _FormButtons(
          saving: _saving,
          saveLabel: _isEditing ? tr('Guardar cambios') : tr('Guardar producto'),
          onSave: _save,
        ),
        if (_isEditing) ...[
          SizedBox(height: 16),
          TextButton.icon(
            onPressed: _saving ? null : _delete,
            icon: Icon(Icons.delete_outline, color: AppColors.danger),
            label: Text(
              tr('Eliminar producto y sus lotes'),
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
        if (others.isNotEmpty) ...[
          SizedBox(height: 28),
          Text(
            tr('¿Ya está registrado?'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            tr('Toca un producto para agregarle un lote nuevo'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          SizedBox(height: 12),
          for (final g in others)
            ZCard(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(10),
              onTap: () => _addLotTo(g),
              child: Row(
                children: [
                  ProductThumbnail(bytes: g.imageBytes, size: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.nombre,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          [
                            if (g.presentacion.isNotEmpty) g.presentacion,
                            tr(g.lots.length == 1 ? '{0} lote' : '{0} lotes', [g.lots.length]),
                          ].join(' · '),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_circle_outline,
                      color: AppColors.primary, size: 22),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Botón grande para escanear: rellena el producto o, si ya existe, lleva
  /// directo a crearle un lote.
  Widget _scanButton() {
    return OutlinedButton.icon(
      onPressed: _scanning ? null : _scan,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
      ),
      icon: _scanning
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.qr_code_scanner),
      label: Text(_scanning
          ? tr('Buscando producto...')
          : tr('Escanear código de barras')),
    );
  }

  Widget _photoPicker() {
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes != null
            ? Image.memory(_imageBytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 34),
                  SizedBox(height: 8),
                  Text(tr('Agregar foto'), style: TextStyle(color: AppColors.textPrimary)),
                  Text(
                    tr('Opcional'),
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// Formulario de LOTE: fecha de vencimiento y cantidad
// =============================================================================

class LotFormScreen extends StatefulWidget {
  const LotFormScreen({super.key, required this.args});

  final LotFormArgs args;

  @override
  State<LotFormScreen> createState() => _LotFormScreenState();
}

class _LotFormScreenState extends State<LotFormScreen> {
  final _repo = ZentoryRepository.instance;
  final _cantidad = TextEditingController();
  DateTime? _fecha;

  String? _storeId;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.args.lotId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Las alertas de vencimiento necesitan permiso de notificaciones.
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && mounted) {
      showMessage(
        context,
        tr('Las notificaciones están desactivadas. No recibirás alertas de vencimiento.'),
        long: true,
      );
    }
    try {
      final storeId = await _repo.resolveActiveStoreId();
      if (!mounted) return;
      if (storeId == null || widget.args.nombre.trim().isEmpty) {
        showMessage(context, tr('No se encontró el producto'));
        Navigator.of(context).maybePop();
        return;
      }
      _storeId = storeId;
      final lotId = widget.args.lotId;
      if (lotId != null) {
        final data = await _repo.fetchProductData(storeId, lotId);
        if (data != null) {
          _cantidad.text = (data['cantidad'] ?? '').toString();
          _fecha = DateUtilsZ.parse(data['fechaVencimiento'] as String?);
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
      // En teléfonos que bloquean el segundo plano (p. ej. ROM chinas),
      // guía una sola vez para dejar listas las alertas.
      maybePromptNotificationSetup(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, tr('Error al cargar: {0}', [e]));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      locale: Locale(currentLanguage.code),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _save() async {
    final cantidad = _cantidad.text.trim();
    final fecha = _fecha;
    final storeId = _storeId;
    if (fecha == null || cantidad.isEmpty) {
      showMessage(context, tr('Indica la fecha de vencimiento y la cantidad'));
      return;
    }
    if (storeId == null) return;

    setState(() => _saving = true);
    final fechaStr = DateUtilsZ.format(fecha);
    try {
      final lotId = widget.args.lotId;
      if (lotId != null) {
        await _repo.updateLot(
          storeId: storeId,
          lotId: lotId,
          cantidad: cantidad,
          fechaVencimiento: fechaStr,
        );
      } else {
        await _repo.addLot(
          storeId: storeId,
          nombre: widget.args.nombre,
          presentacion: widget.args.presentacion,
          imagenBase64: widget.args.imagenBase64,
          cantidad: cantidad,
          fechaVencimiento: fechaStr,
        );
      }
      // Reprograma las alertas de todos los lotes de la tienda
      await NotificationService.instance.syncStore(storeId);
      if (!mounted) return;
      if (_isEditing) {
        showMessage(context, tr('Lote actualizado'));
        Navigator.of(context).pop(true);
      } else {
        showMessage(context, tr('Lote agregado'));
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.productos,
          (r) => r.settings.name == Routes.home,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, tr('No se pudo guardar: {0}', [e]));
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.sendTestNotification();
    if (mounted) showMessage(context, tr('Enviando notificación de prueba...'));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final imageBytes = ImageUtils.decode(a.imagenBase64);
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                onBack: () => Navigator.of(context).maybePop(),
                trailing: IconButton(
                  tooltip: tr('Probar notificación'),
                  icon: Icon(Icons.notifications_active_outlined,
                      color: AppColors.textPrimary),
                  onPressed: _testNotification,
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: EdgeInsets.all(16),
                        children: [
                          _FormTitle(
                            icon: _isEditing
                                ? Icons.edit_outlined
                                : Icons.layers_outlined,
                            title: _isEditing
                                ? tr('Editar lote {0}', [a.lotLabel ?? '']).trim()
                                : tr('Agregar lote'),
                            subtitle: tr('Fecha de vencimiento y cantidad'),
                          ),
                          SizedBox(height: 16),
                          ZCard(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ProductThumbnail(bytes: imageBytes, size: 52),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.nombre,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (a.presentacion.isNotEmpty &&
                                          a.presentacion != 'N/A')
                                        Text(
                                          a.presentacion,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          _DateField(
                            value: _fecha,
                            onTap: _pickDate,
                          ),
                          SizedBox(height: 14),
                          LabeledField(
                            label: tr('Cantidad *'),
                            controller: _cantidad,
                            hint: tr('Ej. 10'),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 24),
                          _FormButtons(
                            saving: _saving,
                            saveLabel:
                                _isEditing ? tr('Guardar cambios') : tr('Guardar lote'),
                            onSave: _save,
                          ),
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

// =============================================================================
// Componentes compartidos por los dos formularios
// =============================================================================

class _FormTitle extends StatelessWidget {
  const _FormTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormButtons extends StatelessWidget {
  const _FormButtons({
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });

  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tr('Cancelar'), maxLines: 1, softWrap: false),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: LoadingButton(
            label: saveLabel,
            loading: saving,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Fecha de vencimiento *'),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined,
                    color: AppColors.textSecondary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v == null ? tr('Selecciona la fecha') : DateUtilsZ.format(v),
                    style: TextStyle(
                      color: v == null ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (v != null)
                  Text(
                    relativeExpiry(v),
                    style: TextStyle(
                      color: ProductStatus.fromExpiry(v).color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Icon(Icons.arrow_drop_down,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
