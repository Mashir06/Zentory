import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_lots.dart';
import '../theme/app_colors.dart';

/// Píldora de estado con los colores de Zentory. Sin estado (producto sin
/// lotes) muestra "Sin lotes".
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.small = false});
  final ProductStatus? status;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: status?.color ?? AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status?.label ?? 'Sin lotes',
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con ícono (se usa para la presentación del producto).
class InfoTag extends StatelessWidget {
  const InfoTag(this.label, {super.key, this.icon = Icons.straighten});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSoft, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de la tabla de lotes: Lote | F. vencimiento | Cantidad | Estado.
class LotTableRow extends StatelessWidget {
  const LotTableRow({
    super.key,
    required this.label,
    required this.lot,
    required this.onTap,
  });

  final String label;
  final Product lot;
  final VoidCallback onTap;

  static const _value = TextStyle(color: Colors.white, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _cell('Lote', Text(label, style: _value)),
            ),
            Expanded(
              flex: 3,
              child: _cell(
                'Vence',
                Text(
                  lot.expiryDate == null ? 'Sin fecha' : lot.fechaVencimiento,
                  style: _value,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _cell('Cantidad', Text(lot.cantidad, style: _value)),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: _cell(
                'Estado',
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: StatusPill(lot.status, small: true),
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _cell(String title, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}

/// Acción elegida en la hoja de detalle de un lote.
enum LotAction { edit, delete }

/// Hoja inferior con el detalle de un lote. Si [allowActions] es `true`
/// muestra los botones Editar / Eliminar y devuelve la acción elegida.
Future<LotAction?> showLotDetailSheet(
  BuildContext context, {
  required Product lot,
  required String label,
  bool allowActions = true,
}) {
  return showModalBottomSheet<LotAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lote $label',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${lot.nombre} · ${lotCode(lot)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(lot.status),
              ],
            ),
            const SizedBox(height: 16),
            _SheetRow('Fecha de vencimiento', lot.fechaVencimiento),
            _SheetRow('', relativeExpiry(lot.expiryDate),
                valueColor: lot.status.color),
            _SheetRow('Cantidad', '${lot.cantidad} unidades'),
            _SheetRow('Presentación', lot.presentacion),
            _SheetRow('Fecha de registro', lot.fechaRegistro),
            const SizedBox(height: 16),
            if (allowActions)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, LotAction.delete),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, LotAction.edit),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar lote'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow(this.label, this.value, {this.valueColor = Colors.white});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight:
                    label.isEmpty ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
