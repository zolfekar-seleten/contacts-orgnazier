import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight ring chart; no charting dependency needed for a few segments.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 104,
    this.thickness = 12,
    this.center,
  });

  final List<double> values;
  final List<Color> colors;
  final double size;
  final double thickness;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DonutPainter(values, colors, thickness),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.thickness);

  final List<double> values;
  final List<Color> colors;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - thickness) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    // Small gap between segments; skipped when there is only one.
    final visible = values.where((v) => v > 0).length;
    final gap = visible > 1 ? 0.10 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
}
