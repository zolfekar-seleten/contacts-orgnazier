// Runs on a simulator/device against the real url_launcher plugin. Contacts
// are faked so no permission prompt is needed. No call is placed and no
// message is sent: the simulator has no dialer, and WhatsApp only ever opens
// with a prefilled draft.
import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/communication/data/platform_url_launcher.dart';
import 'package:country_contacts/features/contact_search/presentation/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(
          repository: FakeContactsRepository(),
          launcher: const PlatformUrlLauncher(),
        ),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'oliver');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
  }

  testWidgets('platform reports call capability honestly', (tester) async {
    await pumpApp(tester);
    final canCall = await const PlatformUrlLauncher().canLaunch(
      Uri.parse('tel:+447400123456'),
    );
    debugPrint('[it] canLaunch(tel:) = $canCall');

    await tester.tap(find.byTooltip('Call Oliver Bennett'));
    await tester.pumpAndSettle();

    if (!canCall) {
      expect(find.text('This device can’t make phone calls.'), findsOneWidget);
    }
  });

  testWidgets('WhatsApp missing -> offers WhatsApp Web fallback', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('WhatsApp Oliver Bennett'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi Oliver! 👋'));
    await tester.tap(find.text('Continue to WhatsApp'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final dialog = find.text('WhatsApp isn’t available');
    final opened = find.text(
      'WhatsApp opened. Review and send your message there.',
    );
    debugPrint(
      '[it] whatsapp app opened: ${opened.evaluate().isNotEmpty}, '
      'fallback dialog: ${dialog.evaluate().isNotEmpty}',
    );
    expect(dialog.evaluate().isNotEmpty || opened.evaluate().isNotEmpty, true);

    if (dialog.evaluate().isNotEmpty) {
      await tester.tap(find.text('Open WhatsApp Web'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final web = find.text('Opened WhatsApp in your browser.');
      debugPrint('[it] web fallback opened: ${web.evaluate().isNotEmpty}');
      expect(web, findsOneWidget);
    }
  });
}
