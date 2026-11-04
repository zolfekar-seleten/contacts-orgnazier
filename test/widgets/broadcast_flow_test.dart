import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/countries/presentation/country_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fixtures.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockUrlLauncher launcher;

  setUp(() => launcher = MockUrlLauncher());

  Future<void> openUk(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(
          repository: FakeContactsRepository(),
          launcher: launcher,
        ),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ukTile = find.descendant(
      of: find.byType(CountryTile),
      matching: find.text('United Kingdom'),
    );
    await tester.scrollUntilVisible(
      ukTile,
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(ukTile);
    await tester.pumpAndSettle();
  }

  testWidgets('select contacts: long-press, toggle, select all, cancel', (
    tester,
  ) async {
    await openUk(tester);

    await tester.longPress(find.text('Oliver Bennett'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('Call Oliver Bennett'), findsNothing);

    await tester.tap(find.text('Amelia Clarke'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('select-all')));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('Deselect all'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-select')), findsOneWidget);
  });

  testWidgets('back button leaves selection mode before leaving screen', (
    tester,
  ) async {
    await openUk(tester);
    await tester.tap(find.byKey(const Key('start-select')));
    await tester.pumpAndSettle();
    expect(find.text('Tap contacts to select them'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-select')), findsOneWidget);
    expect(find.text('Oliver Bennett'), findsOneWidget);
  });

  testWidgets('compose with name placeholders and send one by one', (
    tester,
  ) async {
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    await openUk(tester);

    await tester.tap(find.byKey(const Key('start-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-selected')));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('TO · 3'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('broadcast-field')), 'Hi');
    await tester.tap(find.byKey(const ValueKey('insert-first_name')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('broadcast-field')),
    );
    expect(field.controller!.text, 'Hi {first_name}');

    await tester.enterText(
      find.byKey(const Key('broadcast-field')),
      'Hi {first_name}, this is for {full_name} ({last_name})',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('preview-text')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Recipients are sorted by name: Amelia, Emily, Oliver.
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-text'))).data,
      'Hi Amelia, this is for Amelia Clarke (Clarke)',
    );
    await tester.tap(find.byTooltip('Next preview'));
    await tester.pump();
    expect(
      find.text('Hi Emily, this is for Emily Johnson (Johnson)'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('review-send')));
    await tester.pumpAndSettle();
    expect(find.text('Send via WhatsApp'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);
    verifyNever(() => launcher.launchInApp(any()));

    await tester.tap(find.byKey(const Key('open-current')));
    await tester.pumpAndSettle();
    // Amelia is in the UK screen, so her UK mobile is preferred.
    final first =
        verify(() => launcher.launchInApp(captureAny())).captured.single as Uri;
    expect(first.host, 'wa.me');
    expect(first.path, '/447400654321');
    expect(
      Uri.decodeComponent(first.query.substring(5)),
      'Hi Amelia, this is for Amelia Clarke (Clarke)',
    );
    expect(find.text('1 of 3'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('current-recipient'))).data,
      'Emily Johnson',
    );

    await tester.tap(find.byKey(const Key('skip-current')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-current')));
    await tester.pumpAndSettle();

    final summary = tester
        .widget<Text>(find.byKey(const Key('broadcast-summary')))
        .data!;
    expect(summary, contains('2 chats opened in WhatsApp, 1 skipped'));
    expect(summary, contains('only sent when you tapped send'));

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-select')), findsOneWidget);
  });

  testWidgets('switching to SMS includes numbers WhatsApp cannot use', (
    tester,
  ) async {
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(
          repository: FakeContactsRepository(
            contacts: [
              contact('1', 'Omar Haddad', ['050 765 4321']),
              contact('2', 'Mystery', ['12345']),
            ],
          ),
          launcher: launcher,
          deviceRegion: null,
        ),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omar Haddad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-selected')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no number with a country code'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('broadcast-field')),
      'Hello {first_name}',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-send')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no number with a country code'), findsNothing);

    await tester.tap(find.byKey(const Key('review-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-current')));
    await tester.pumpAndSettle();

    final uri =
        verify(() => launcher.launchInApp(captureAny())).captured.single as Uri;
    expect(uri.scheme, 'sms');
    expect(uri.toString(), 'sms:0507654321?body=Hello%20Omar');
    expect(find.textContaining('chat opened in Messages'), findsOneWidget);
  });
}
