// Renders the app icon artwork to PNGs using Flutter's own painter.
//
//   flutter test tool/icon/render_icon_test.dart
//
// Writes to assets/icon/:
//   icon.png            1024² full-bleed (iOS, legacy Android)
//   foreground.png      1024² transparent art (inset 16% when generated)
//   background.png      1024² gradient only (Android adaptive background)
//   monochrome.png      1024² white silhouette (Android 13 themed icons)
// Then run `dart run flutter_launcher_icons` to produce platform icon sets.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

const _navy = ui.Color(0xFF14224A);
const _indigo = ui.Color(0xFF3346C4);
const _white = ui.Color(0xFFFFFFFF);
const _pins = [
  ui.Color(0xFFFFC870), // amber
  ui.Color(0xFF5EE0BF), // teal
  ui.Color(0xFFFF8FAB), // pink
];

void _background(ui.Canvas canvas) {
  const rect = ui.Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(_size, _size),
        [_navy, _indigo],
      ),
  );
  // Soft highlight top-right for depth.
  canvas.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(_size * 0.82, _size * 0.12),
        _size * 0.75,
        [const ui.Color(0x557C9BFF), const ui.Color(0x007C9BFF)],
      ),
  );
}

/// Globe ring, faint meridians, contact silhouette and country pins.
/// [mono] draws everything in solid white (themed icons).
void _art(ui.Canvas canvas, {double scale = 1, bool mono = false}) {
  canvas.save();
  canvas.translate(_size / 2, _size / 2);
  canvas.scale(scale);

  const ringRadius = 330.0;
  const ringWidth = 46.0;
  final white = ui.Paint()..color = _white;
  final faint = ui.Paint()
    ..color = mono ? _white : _white.withValues(alpha: 0.32)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 20;

  // Meridian and equator, clipped inside the ring.
  canvas.save();
  canvas.clipPath(
    ui.Path()
      ..addOval(ui.Rect.fromCircle(center: ui.Offset.zero, radius: ringRadius)),
  );
  if (!mono) {
    canvas.drawOval(
      ui.Rect.fromCenter(center: ui.Offset.zero, width: 330, height: 660),
      faint,
    );
    canvas.drawLine(
      const ui.Offset(-ringRadius, 0),
      const ui.Offset(ringRadius, 0),
      faint,
    );
  }

  // Contact silhouette: head and shoulders, shoulders cut by the ring.
  canvas.drawCircle(const ui.Offset(0, -70), 112, white);
  canvas.drawPath(
    ui.Path()..addOval(
      ui.Rect.fromCenter(
        center: const ui.Offset(0, 250),
        width: 420,
        height: 330,
      ),
    ),
    white,
  );
  canvas.restore();

  // Separation gap between silhouette and ring.
  canvas.drawCircle(
    ui.Offset.zero,
    ringRadius,
    ui.Paint()
      ..color = _white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = ringWidth,
  );

  // Country pins sitting on the ring.
  const angles = [-50.0, 200.0, 130.0];
  for (var i = 0; i < angles.length; i++) {
    final a = angles[i] * math.pi / 180;
    final c = ui.Offset(math.cos(a) * ringRadius, math.sin(a) * ringRadius);
    if (!mono) {
      // Navy halo so pins read separately from the ring.
      canvas.drawCircle(c, 64, ui.Paint()..color = _navy);
    }
    canvas.drawCircle(c, 46, ui.Paint()..color = mono ? _white : _pins[i]);
  }
  canvas.restore();
}

Future<void> _write(String path, void Function(ui.Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  test('render icon artwork', () async {
    await _write('assets/icon/icon.png', (c) {
      _background(c);
      _art(c, scale: 0.86);
    });
    await _write('assets/icon/background.png', _background);
    // flutter_launcher_icons insets adaptive layers by 16%, which keeps
    // full-size art inside Android's 66% safe zone.
    await _write('assets/icon/foreground.png', _art);
    await _write('assets/icon/monochrome.png', (c) => _art(c, mono: true));
  });
}
