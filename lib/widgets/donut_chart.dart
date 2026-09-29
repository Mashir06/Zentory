import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gráfica de dona por categorías (reemplaza DonutChartView).
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 140,
  });

  final Map<String, int> values;
  final Map<String, Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DonutPainter(values, colors)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);

  final Map<String, int> values;
  final Map<String, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 10.0;
    final diameter = math.min(size.width, size.height) - padding * 2;
    final stroke = diameter * 0.15;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: diameter - stroke,
      height: diameter - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final total = values.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) {
      paint.color = AppColors.border;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    var start = -math.pi / 2;
    for (final entry in values.entries) {
      if (entry.value <= 0) continue;
      final sweep = entry.value / total * math.pi * 2;
      paint.color = colors[entry.key] ?? Colors.grey;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}
