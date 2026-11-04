import 'package:country_contacts/core/widgets/whatsapp_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps its size inside a dialog icon slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            icon: WhatsAppIcon(size: 36),
            title: Text('WhatsApp isn’t available'),
          ),
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byType(WhatsAppIcon),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(paint), const Size(36, 36));
  });
}
