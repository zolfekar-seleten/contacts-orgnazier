import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// WhatsApp-style glyph: a round speech bubble with a handset, drawn without
/// pulling in an icon-font dependency.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.whatsApp;
    return Semantics(
      label: 'WhatsApp',
      // Align loosens tight parent constraints (e.g. a dialog's stretched
      // icon slot) so the glyph keeps its own size.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _BubblePainter(c),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(right: size * 0.02),
                child: Icon(Icons.call, size: size * 0.46, color: c),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.085;
    final center = Offset(s * 0.53, s * 0.47);
    final radius = s * 0.40;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Bubble arc leaves a gap at the bottom-left for the tail.
    const gapStart = math.pi * 0.62;
    const gap = math.pi * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..addArc(rect, gapStart + gap, math.pi * 2 - gap)
      ..lineTo(s * 0.10, s * 0.92)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => oldDelegate.color != color;
}
