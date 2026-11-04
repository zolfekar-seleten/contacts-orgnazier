import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/contacts/presentation/contact_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fixtures.dart';

/// 23:30 in the UK (summer time); 22:30 UTC.
final ukLateNight = DateTime.utc(2026, 6, 15, 22, 30);

void main() {
  setUpAll(registerFallbacks);

  late MockUrlLauncher launcher;

  setUp(() {
    launcher = MockUrlLauncher();
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
  });

  Future<void> openUk(WidgetTester tester, {DateTime? now}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(
          repository: FakeContactsRepository(),
          launcher: launcher,
          now: now,
        ),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-GB')));
    await tester.pumpAndSettle();
  }

  List<String> listedNames(WidgetTester tester) => tester
      .widgetList<ContactTile>(find.byType(ContactTile))
      .map((t) => t.contact.displayName)
      .toList();

  group('sort and filter', () {
    testWidgets('filter chips show counts and narrow the list', (tester) async {
      await openUk(tester);

      expect(find.text('All 3'), findsOneWidget);
      expect(find.text('Mobile 3'), findsOneWidget);
      expect(find.text('Landline 1'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('filter-landline')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-landline')));
      await tester.pumpAndSettle();
      expect(listedNames(tester), ['Amelia Clarke']);

      await tester.ensureVisible(find.byKey(const ValueKey('filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-all')));
      await tester.pumpAndSettle();
      expect(listedNames(tester), hasLength(3));
    });

    testWidgets('sort menu reorders by last name', (tester) async {
      await openUk(tester);
      expect(listedNames(tester), [
        'Amelia Clarke',
        'Emily Johnson',
        'Oliver Bennett',
      ]);

      await tester.tap(find.byKey(const Key('sort-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sort-lastName')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sort: Last name'), findsOneWidget);
      expect(listedNames(tester), [
        'Oliver Bennett',
        'Amelia Clarke',
        'Emily Johnson',
      ]);
    });

    testWidgets('select all only selects what the filter shows', (
      tester,
    ) async {
      await openUk(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('filter-landline')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-landline')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('local time', () {
    testWidgets('banner and details show the local time', (tester) async {
      await openUk(tester);
      expect(find.text('1:00 PM there now'), findsOneWidget);

      await tester.tap(find.text('Oliver Bennett'));
      await tester.pumpAndSettle();
      expect(find.text('1:00 PM local time'), findsOneWidget);
    });

    testWidgets('late at night: marked, and calling asks first', (
      tester,
    ) async {
      await openUk(tester, now: ukLateNight);
      expect(find.text('11:30 PM there now · late night'), findsOneWidget);

      await tester.tap(find.byTooltip('Call Oliver Bennett'));
      await tester.pumpAndSettle();
      expect(find.text('It’s 11:30 PM in United Kingdom'), findsOneWidget);
      expect(find.text('It may be a bad time to call Oliver.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => launcher.launchInApp(any()));

      await tester.tap(find.byTooltip('Call Oliver Bennett'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('late-night-continue')));
      await tester.pumpAndSettle();
      verify(
        () => launcher.launchInApp(Uri.parse('tel:+447400123456')),
      ).called(1);
    });

    testWidgets('messaging late at night asks before the composer', (
      tester,
    ) async {
      await openUk(tester, now: ukLateNight);
      await tester.tap(find.byTooltip('WhatsApp Oliver Bennett'));
      await tester.pumpAndSettle();

      expect(find.text('Message anyway'), findsOneWidget);
      expect(find.text('Continue to WhatsApp'), findsNothing);
      await tester.tap(find.byKey(const Key('late-night-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Continue to WhatsApp'), findsOneWidget);
    });

    testWidgets('daytime calls go straight to the dialer', (tester) async {
      await openUk(tester);
      await tester.tap(find.byTooltip('Call Oliver Bennett'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('late-night-continue')), findsNothing);
      verify(
        () => launcher.launchInApp(Uri.parse('tel:+447400123456')),
      ).called(1);
    });
  });

  group('bulk messages', () {
    Future<void> composeToAllUk(WidgetTester tester, {DateTime? now}) async {
      await openUk(tester, now: now);
      await tester.tap(find.byKey(const Key('start-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('message-selected')));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const Key('broadcast-field')))
        .controller!
        .text;

    testWidgets('a saved template fills the message', (tester) async {
      await composeToAllUk(tester);
      await tester.tap(find.byKey(const ValueKey('template-starter-eid')));
      await tester.pump();

      expect(fieldText(tester), startsWith('Eid Mubarak, {first_name}!'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('preview-text')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-text'))).data,
        startsWith('Eid Mubarak, Amelia!'),
      );
    });

    testWidgets('save the current message, then delete it', (tester) async {
      await composeToAllUk(tester);
      await tester.enterText(
        find.byKey(const Key('broadcast-field')),
        'Ramadan Kareem, {first_name}!',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save-template')));
      await tester.tap(find.byKey(const Key('save-template')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('template-name')), 'Ramadan');
      await tester.tap(find.byKey(const Key('template-save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved “Ramadan”.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('broadcast-field')), '');
      await tester.ensureVisible(find.byKey(const Key('manage-templates')));
      await tester.tap(find.byKey(const Key('manage-templates')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Ramadan'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Delete Ramadan'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete Ramadan'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('saved-starter-meeting')));
      await tester.pumpAndSettle();
      expect(
        fieldText(tester),
        startsWith('Hi {first_name}, a quick reminder'),
      );
    });

    testWidgets('warns when it is late for recipients', (tester) async {
      await composeToAllUk(tester, now: ukLateNight);
      expect(
        find.textContaining('It’s late at night for 3 recipients'),
        findsOneWidget,
      );
    });

    testWidgets('no late-night notice in the daytime', (tester) async {
      await composeToAllUk(tester);
      expect(find.byKey(const Key('late-night-notice')), findsNothing);
    });
  });
}
