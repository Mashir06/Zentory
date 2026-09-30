import 'dart:typed_data';

import 'package:flutter/material.dart';

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
