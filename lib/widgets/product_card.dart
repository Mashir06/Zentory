import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';

/// Miniatura cuadrada de un producto (o un ícono si no tiene foto).
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, this.bytes, this.size = 56});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: AppColors.border,
        child: bytes != null
            ? Image.memory(
                bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Icon(
        Icons.image_outlined,
        color: AppColors.textSecondary,
        size: size * 0.5,
      );
}

/// Tarjeta de producto expandible (equivale a item_producto.xml).
class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.subtitle,
    this.onEdit,
    this.onDelete,
    this.initiallyExpanded = false,
  });

  final Product product;
  final String? subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool initiallyExpanded;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final status = p.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ProductThumbnail(bytes: p.imageBytes),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.nombre} (${p.cantidad})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle ??
                                '${p.categoria}\nVence: ${p.fechaVencimiento}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _details(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(Product p) {
    final status = p.status;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.border),
          _row('Categoría', Text(p.categoria, style: _valueStyle)),
          _row('Marca', Text(p.marca, style: _valueStyle)),
          _row('Presentación', Text(p.presentacion, style: _valueStyle)),
          _row('Fecha de registro', Text(p.fechaRegistro, style: _valueStyle)),
          _row('Fecha de vencimiento',
              Text(p.fechaVencimiento, style: _valueStyle)),
          _row(
            'Estado',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(status.label, style: _valueStyle),
              ],
            ),
          ),
          _row('Cantidad', Text('${p.cantidad} unidades', style: _valueStyle)),
          if (widget.onEdit != null || widget.onDelete != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar producto'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                if (widget.onEdit != null && widget.onDelete != null)
                  const SizedBox(width: 10),
                if (widget.onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar producto'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _valueStyle = TextStyle(color: Colors.white, fontSize: 13);

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}
