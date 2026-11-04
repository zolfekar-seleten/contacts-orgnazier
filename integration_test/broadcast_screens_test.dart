// Walks the real app (real device contacts, real launcher) through the
// select -> compose -> send flow and captures a screenshot at each step.
// Requires contacts permission to be granted already. Nothing is sent: the
// test only opens chats, and on a simulator WhatsApp is not installed.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/broadcast_screens_test.dart -d <device>
import 'package:country_contacts/main.dart' as app;
import 'package:country_contacts/features/contacts/presentation/contact_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets('broadcast flow screenshots', (tester) async {
    app.main();
    // Wait for the address book to load and classify.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const ValueKey('top-GB')).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await shot(tester, '01_home');

    // Open the United Kingdom from the Top countries carousel.
    await tester.tap(find.byKey(const ValueKey('top-GB')));
    await shot(tester, '02_country');

    await tester.tap(find.byKey(const Key('start-select')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(ContactTile).at(i));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shot(tester, '03_selected');

    await tester.tap(find.byKey(const Key('message-selected')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('broadcast-field')), 'Hi');
    await tester.tap(find.byKey(const ValueKey('insert-first_name')));
    await tester.pump();
    final field = find.byKey(const Key('broadcast-field'));
    final controller = tester.widget<TextField>(field).controller!;
    controller.text =
        '${controller.text}! Quick note for {full_name} – are you around '
        'this week?';
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '04_compose');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await shot(tester, '05_preview');

    await tester.tap(find.text('SMS'));
    await shot(tester, '06_compose_sms');
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review-send')));
    await shot(tester, '07_send_queue');

    await tester.tap(find.byKey(const Key('open-current')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shot(tester, '08_whatsapp_missing');
    if (find.text('Cancel').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 3; i++) {
      if (find.byKey(const Key('skip-current')).evaluate().isEmpty) break;
      await tester.tap(find.byKey(const Key('skip-current')));
      await tester.pumpAndSettle();
    }
    await shot(tester, '09_done');
  });
}
