import 'package:flutter/material.dart';

import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';

/// Diálogo para crear o editar una tienda (equivale a dialog_add_minisuper.xml).
///
/// [onSubmit] hace el trabajo; si lanza un error, el mensaje se muestra dentro
/// del diálogo. Devuelve `true` si se guardó.
Future<bool> showStoreFormDialog(
  BuildContext context, {
  String title = 'Agregar Nuevo Minisuper',
  String confirmLabel = 'Crear',
  String initialNombre = '',
  String initialUbicacion = '',
  required Future<void> Function(String nombre, String ubicacion) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StoreFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialNombre: initialNombre,
      initialUbicacion: initialUbicacion,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

/// Diálogo para unirse a una tienda con código (equivale a dialog_join_store.xml).
Future<bool> showJoinStoreDialog(
  BuildContext context, {
  required Future<void> Function(String code) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _JoinStoreDialog(onSubmit: onSubmit),
  );
  return result ?? false;
}

String _errorText(Object e) =>
    e is ZentoryException ? e.message : 'Ocurrió un error: $e';

class _StoreFormDialog extends StatefulWidget {
  const _StoreFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialNombre,
    required this.initialUbicacion,
    required this.onSubmit,
  });

  final String title;
  final String confirmLabel;
  final String initialNombre;
  final String initialUbicacion;
  final Future<void> Function(String, String) onSubmit;

  @override
  State<_StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends State<_StoreFormDialog> {
  late final _nombre = TextEditingController(text: widget.initialNombre);
  late final _ubicacion = TextEditingController(text: widget.initialUbicacion);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(nombre, _ubicacion.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: widget.title,
      error: _error,
      saving: _saving,
      confirmLabel: widget.confirmLabel,
      onConfirm: _save,
      children: [
        TextField(
          controller: _nombre,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre del Minisuper',
            fillColor: AppColors.background,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ubicacion,
          enabled: !_saving,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ubicación / Dirección',
            fillColor: AppColors.background,
          ),
        ),
      ],
    );
  }
}

class _JoinStoreDialog extends StatefulWidget {
  const _JoinStoreDialog({required this.onSubmit});
  final Future<void> Function(String) onSubmit;

  @override
  State<_JoinStoreDialog> createState() => _JoinStoreDialogState();
}

class _JoinStoreDialogState extends State<_JoinStoreDialog> {
  final _code = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'El código es obligatorio');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(code);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Unirse a una Tienda',
      error: _error,
      saving: _saving,
      confirmLabel: 'Unirse',
      onConfirm: _join,
      children: [
        TextField(
          controller: _code,
          enabled: !_saving,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, letterSpacing: 2),
          decoration: const InputDecoration(
            hintText: 'Código de Invitación',
            fillColor: AppColors.background,
          ),
        ),
      ],
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
    required this.saving,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onConfirm,
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
