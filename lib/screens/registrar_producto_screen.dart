import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/categories.dart';
import '../models/product.dart';
import '../routes.dart';
import '../services/notification_service.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/image_utils.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/notification_setup_sheet.dart';
import '../widgets/product_card.dart';

/// Registrar o editar un producto (equivale a RegistrarProductoScreen).
class RegistrarProductoScreen extends StatefulWidget {
  const RegistrarProductoScreen({super.key, this.args = const AddProductArgs()});

  final AddProductArgs args;

  @override
  State<RegistrarProductoScreen> createState() =>
      _RegistrarProductoScreenState();
}

class _RegistrarProductoScreenState extends State<RegistrarProductoScreen> {
  final _repo = ZentoryRepository.instance;
  final _picker = ImagePicker();

  late final _nombre = TextEditingController(text: widget.args.qrNombre ?? '');
  late final _marca = TextEditingController(text: widget.args.qrMarca ?? '');
  late final _presentacion =
      TextEditingController(text: widget.args.qrPresentacion ?? '');
  final _cantidad = TextEditingController();

  late String? _categoria = widget.args.qrCategoria;
  DateTime? _fecha;

  /// Imagen actual en Base64 (la del producto, la del catálogo o la nueva).
  String? _imagenBase64;
  Uint8List? _imageBytes;

  String? _storeId;
  List<CatalogItem> _catalog = [];
  bool _loading = true;
  bool _saving = false;
  Timer? _debounce;

  bool get _isEditing => widget.args.productId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nombre.dispose();
    _marca.dispose();
    _presentacion.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Pedir permiso de notificaciones para las alertas de vencimiento
    final granted = await NotificationService.instance.requestPermission();
    if (!granted && mounted) {
      showMessage(
        context,
        'Las notificaciones están desactivadas. No recibirás alertas de vencimiento.',
        long: true,
      );
    }

    try {
      final storeId = await _repo.resolveActiveStoreId();
      if (!mounted) return;
      if (storeId == null) {
        showMessage(context, 'No tienes una tienda vinculada');
        Navigator.of(context).maybePop();
        return;
      }
      _storeId = storeId;

      final productId = widget.args.productId;
      if (productId != null) {
        final data = await _repo.fetchProductData(storeId, productId);
        if (data != null) {
          _nombre.text = (data['nombre'] ?? '').toString();
          _categoria = data['categoria'] as String?;
          _marca.text = (data['marca'] ?? '').toString();
          _presentacion.text = (data['presentacion'] ?? '').toString();
          _cantidad.text = (data['cantidad'] ?? '').toString();
          _fecha = DateUtilsZ.parse(data['fechaVencimiento'] as String?);
          _setImage(data['imagen'] as String?);
        }
      }

      final catalog = await _repo.fetchCatalog(storeId);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
      // En teléfonos que bloquean el segundo plano (p. ej. ROM chinas),
      // guía una sola vez para dejar listas las alertas.
      if (mounted) maybePromptNotificationSetup(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, 'Error al cargar: $e');
    }
  }

  void _setImage(String? base64) {
    _imagenBase64 = (base64 == null || base64.isEmpty) ? null : base64;
    _imageBytes = ImageUtils.decode(_imagenBase64);
  }

  /// Al escribir el nombre, busca el producto en el catálogo y autocompleta.
  void _onNameChanged(String value) {
    if (_isEditing) return;
    _debounce?.cancel();
    final nombre = value.trim();
    if (nombre.length <= 2 || _storeId == null) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final item = await _repo.findInCatalog(_storeId!, nombre);
      if (item == null || !mounted) return;
      _applyCatalog(item, message: 'Producto encontrado en catálogo');
    });
  }

  void _applyCatalog(CatalogItem item, {String? message}) {
    setState(() {
      if (_nombre.text.trim() != item.nombre) _nombre.text = item.nombre;
      _categoria = item.categoria;
      _marca.text = item.marca;
      _presentacion.text = item.presentacion;
      if (item.imagenBase64 != null && item.imagenBase64!.isNotEmpty) {
        _setImage(item.imagenBase64);
      }
    });
    if (message != null) showMessage(context, message);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Cámara', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title:
                  const Text('Galería', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Igual que la app Kotlin: JPEG de 400 px de ancho al 70 % de calidad.
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
      if (mounted) showMessage(context, 'No se pudo obtener la foto: $e');
    }
  }

  Future<void> _pickCategory() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Selecciona una categoría',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final c in kProductCategories)
              ListTile(
                title: Text(c, style: const TextStyle(color: Colors.white)),
                trailing: c == _categoria
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (value != null) setState(() => _categoria = value);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final cantidad = _cantidad.text.trim();
    final categoria = _categoria;
    final fecha = _fecha;
    final storeId = _storeId;

    if (nombre.isEmpty ||
        categoria == null ||
        fecha == null ||
        cantidad.isEmpty) {
      showMessage(context, 'Faltan datos obligatorios (*)');
      return;
    }
    if (storeId == null) return;

    setState(() => _saving = true);
    final fechaStr = DateUtilsZ.format(fecha);
    try {
      await _repo.saveProduct(
        storeId: storeId,
        productId: widget.args.productId,
        nombre: nombre,
        categoria: categoria,
        marca: _marca.text.trim(),
        presentacion: _presentacion.text.trim(),
        cantidad: cantidad,
        fechaVencimiento: fechaStr,
        imagenBase64: _imagenBase64,
      );
      // Reprograma las alertas de todos los lotes de la tienda
      await NotificationService.instance.syncStore(storeId);
      if (!mounted) return;
      if (_isEditing) showMessage(context, 'Actualizado');
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.productos,
        (r) => r.settings.name == Routes.home,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'No se pudo guardar: $e');
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.sendTestNotification();
    if (mounted) showMessage(context, 'Enviando notificación de prueba...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                onBack: () => Navigator.of(context).maybePop(),
                trailing: IconButton(
                  tooltip: 'Probar notificación',
                  icon: const Icon(Icons.notifications_active_outlined,
                      color: Colors.white),
                  onPressed: _testNotification,
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _form(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Editar producto' : 'Agregar producto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isEditing
                        ? 'Actualiza la información del producto'
                        : 'Completa la información del nuevo producto',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle('Información del producto'),
        const SizedBox(height: 12),
        Center(child: _photoPicker()),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Nombre del producto *',
          controller: _nombre,
          hint: 'Ej. Leche Chiricana 946ml',
          textCapitalization: TextCapitalization.sentences,
          onChanged: _onNameChanged,
        ),
        const SizedBox(height: 14),
        _selectorField(
          label: 'Categoría *',
          value: _categoria,
          placeholder: 'Selecciona una categoría',
          icon: Icons.category_outlined,
          onTap: _pickCategory,
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Marca',
          controller: _marca,
          hint: 'Ej. Chiricana',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Presentación',
          controller: _presentacion,
          hint: 'Ej. 946ml, 1 litro',
        ),
        const SizedBox(height: 24),
        _sectionTitle('Información de vencimiento y cantidad'),
        const SizedBox(height: 12),
        _selectorField(
          label: 'Fecha de vencimiento *',
          value: _fecha == null ? null : DateUtilsZ.format(_fecha!),
          placeholder: 'Selecciona la fecha',
          icon: Icons.event_outlined,
          onTap: _pickDate,
        ),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Cantidad *',
          controller: _cantidad,
          hint: 'Ej. 10',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: LoadingButton(
                label: _isEditing ? 'Actualizar producto' : 'Guardar producto',
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
        if (_catalog.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionTitle('Productos frecuentes (Catálogo)'),
          const Text(
            'Toca un producto para autocompletar el formulario',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final item in _catalog)
            ZCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              onTap: () => _applyCatalog(
                item,
                message: 'Información cargada de: ${item.nombre}',
              ),
              child: Row(
                children: [
                  ProductThumbnail(bytes: item.imageBytes, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${item.categoria} | ${item.marca}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.north_west,
                      color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

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
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 34),
                  SizedBox(height: 8),
                  Text('Agregar foto', style: TextStyle(color: Colors.white)),
                  Text(
                    'Opcional',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _selectorField({
    required String label,
    required String? value,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: value == null ? AppColors.textMuted : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
