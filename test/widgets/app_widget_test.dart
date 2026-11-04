import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/contact_search/presentation/search_providers.dart';
import 'package:country_contacts/features/contacts/domain/contacts_repository.dart';
import 'package:country_contacts/features/countries/presentation/country_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fixtures.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockUrlLauncher launcher;
  setUp(() => launcher = MockUrlLauncher());

  Future<FakeContactsRepository> pumpApp(
    WidgetTester tester, {
    FakeContactsRepository? repository,
  }) async {
    final repo = repository ?? FakeContactsRepository();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(repository: repo, launcher: launcher),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  final mainScrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  // Country names also appear in the Top countries carousel.
  Finder inCountryList(String text) =>
      find.descendant(of: find.byType(CountryTile), matching: find.text(text));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
  }

  group('permission states', () {
    testWidgets('explains access before requesting it', (tester) async {
      final repo = await pumpApp(
        tester,
        repository: FakeContactsRepository(
          status: ContactsPermission.notDetermined,
        ),
      );

      expect(find.text('See your contacts by country'), findsOneWidget);
      expect(find.textContaining('Never uploaded'), findsOneWidget);
      expect(repo.requestCount, 0);

      await tester.tap(find.text('Allow contacts access'));
      await tester.pumpAndSettle();

      expect(repo.requestCount, 1);
      expect(find.text('Total contacts'), findsOneWidget);
    });

    testWidgets('denied offers to try again', (tester) async {
      await pumpApp(
        tester,
        repository: FakeContactsRepository(status: ContactsPermission.denied),
      );
      expect(find.text('Contacts access needed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('permanently denied links to Settings', (tester) async {
      final repo = await pumpApp(
        tester,
        repository: FakeContactsRepository(
          status: ContactsPermission.permanentlyDenied,
        ),
      );
      expect(find.text('Turn on contacts access'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      expect(repo.openSettingsCount, 1);
    });
  });

  testWidgets('shows an empty state without contacts', (tester) async {
    await pumpApp(tester, repository: FakeContactsRepository(contacts: []));
    expect(find.text('No contacts with phone numbers'), findsOneWidget);
  });

  testWidgets('shows an error state with retry', (tester) async {
    final repo = await pumpApp(
      tester,
      repository: FakeContactsRepository(error: Exception('nope')),
    );
    expect(find.text('Something went wrong'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Total contacts'), findsOneWidget);
  });

  testWidgets('renders totals, countries and Unknown', (tester) async {
    await pumpApp(tester);

    expect(find.text('Total contacts'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('TOP COUNTRIES'), findsOneWidget);
    await tester.scrollUntilVisible(
      inCountryList('India'),
      200,
      scrollable: mainScrollable,
    );
    for (final name in ['United Kingdom', 'United States', 'India']) {
      expect(inCountryList(name), findsOneWidget);
    }
    expect(find.text('+44'), findsOneWidget);
    expect(find.text('🇬🇧 43%'), findsOneWidget); // overview legend, 3 of 7
    expect(inCountryList('43%'), findsOneWidget);
    expect(find.text('9'), findsOneWidget); // distinct numbers
    await tester.scrollUntilVisible(
      find.text('Unknown'),
      200,
      scrollable: mainScrollable,
    );
    expect(find.text('Unknown'), findsOneWidget);
  });

  group('number in contact rows', () {
    testWidgets('prefers the mobile number and counts the rest', (
      tester,
    ) async {
      await pumpApp(tester);
      await search(tester, 'amelia');
      // Amelia's landline is listed first; the row shows her mobile.
      expect(find.text('+44 7400 654321'), findsOneWidget);
      expect(find.text('+44 20 7946 0958'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    for (final scale in [1.0, 1.6]) {
      testWidgets('is shown in full on a 320pt screen at x$scale text', (
        tester,
      ) async {
        await pumpApp(
          tester,
          repository: FakeContactsRepository(
            contacts: [
              contact('1', 'Maximilian Alexander Featherstonehaugh', [
                '+971 50 123 4567',
                '+971 55 987 6543',
              ]),
            ],
          ),
        );
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpAndSettle();
        await search(tester, 'max');

        final number = find.byKey(const Key('tile-number'));
        expect(tester.widget<Text>(number).data, '+971 50 123 4567');
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: number, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        // The whole number sits inside the screen.
        final rect = tester.getRect(number);
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.left, greaterThanOrEqualTo(0));
      });
    }
  });

  testWidgets('top countries carousel opens a country', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('top-IN')));
    await tester.pumpAndSettle();
    expect(find.text('+91  ·  IN'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
  });

  testWidgets('long-pressing a number copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpApp(tester);
    await search(tester, 'oliver');
    await tester.tap(find.text('Oliver Bennett'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('+44 7400 123456'));
    await tester.pumpAndSettle();
    expect(copied, '+447400123456');
    expect(find.text('Copied +447400123456'), findsOneWidget);
  });

  testWidgets('search finds contacts and countries', (tester) async {
    await pumpApp(tester);

    await search(tester, 'oliver');
    expect(find.text('Oliver Bennett'), findsOneWidget);
    expect(find.text('Total contacts'), findsNothing);

    await search(tester, '+91');
    expect(find.text('India'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);

    await search(tester, 'qqqq');
    expect(find.text('No results'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Total contacts'), findsOneWidget);
  });

  testWidgets('selecting a country lists only its contacts', (tester) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(
      inCountryList('United States'),
      200,
      scrollable: mainScrollable,
    );
    await tester.tap(inCountryList('United States'));
    await tester.pumpAndSettle();

    expect(find.text('+1  ·  US'), findsOneWidget);
    expect(find.text('James Miller'), findsOneWidget);
    expect(find.text('Emily Johnson'), findsOneWidget);
    expect(find.text('Oliver Bennett'), findsNothing);
    // Emily's row shows her US number, not her UK one.
    expect(find.text('+1 415-555-2671'), findsOneWidget);

    await search(tester, 'james');
    expect(find.text('Emily Johnson'), findsNothing);
    expect(find.text('James Miller'), findsOneWidget);
  });

  testWidgets('contact details show each number with its country', (
    tester,
  ) async {
    await pumpApp(tester);
    await search(tester, 'emily');
    await tester.tap(find.text('Emily Johnson'));
    await tester.pumpAndSettle();

    expect(find.text('Emily Johnson'), findsOneWidget);
    expect(find.text('+1 415 555 2671'), findsOneWidget);
    expect(find.text('+44 7400 222333'), findsOneWidget);
    expect(find.text('United States  ·  +1'), findsOneWidget);
    expect(find.text('United Kingdom  ·  +44'), findsOneWidget);
    expect(find.byKey(const Key('details-call')), findsOneWidget);
    expect(find.byKey(const Key('details-whatsapp')), findsOneWidget);
  });

  group('editing', () {
    Future<FakeContactsRepository> openEmily(
      WidgetTester tester,
      FakeContactsRepository repo,
    ) async {
      await pumpApp(tester, repository: repo);
      await search(tester, 'emily');
      await tester.tap(find.text('Emily Johnson'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('saving in the system editor refreshes the details', (
      tester,
    ) async {
      final repo = FakeContactsRepository()
        ..contactsAfterEdit = [
          for (final c in sampleContacts)
            c.id == '4'
                ? contact('4', 'Emily Stone', ['+33 6 12 34 56 78'])
                : c,
        ];
      await openEmily(tester, repo);

      await tester.tap(find.byKey(const Key('details-edit')));
      await tester.pumpAndSettle();

      expect(repo.editedIds, ['4']);
      expect(find.text('Contact updated.'), findsOneWidget);
      expect(find.text('Emily Stone'), findsOneWidget);
      expect(find.text('France  ·  +33'), findsOneWidget);
    });

    testWidgets('cancelling leaves the contact untouched', (tester) async {
      final repo = FakeContactsRepository()
        ..editResult = ContactEditResult.cancelled;
      await openEmily(tester, repo);
      final fetches = repo.fetchCount;

      await tester.tap(find.byKey(const Key('details-edit')));
      await tester.pumpAndSettle();

      expect(repo.fetchCount, fetches);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Emily Johnson'), findsOneWidget);
    });

    testWidgets('reports when the editor cannot open', (tester) async {
      final repo = FakeContactsRepository()
        ..editResult = ContactEditResult.unavailable;
      await openEmily(tester, repo);

      await tester.tap(find.byKey(const Key('details-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t open the contacts editor.'), findsOneWidget);
    });
  });

  group('calling', () {
    testWidgets('multiple numbers: user picks one, then the dialer opens', (
      tester,
    ) async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
      await pumpApp(tester);
      await search(tester, 'emily');
      await tester.tap(find.text('Emily Johnson'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details-call')));
      await tester.pumpAndSettle();
      expect(find.text('Call Emily Johnson'), findsOneWidget);
      verifyNever(() => launcher.launchInApp(any()));

      await tester.tap(find.text('+44 7400 222333').last);
      await tester.pumpAndSettle();
      verify(
        () => launcher.launchInApp(Uri.parse('tel:+447400222333')),
      ).called(1);
    });

    testWidgets('reports devices that cannot call', (tester) async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => false);
      await pumpApp(tester);
      await search(tester, 'oliver');
      await tester.tap(find.byTooltip('Call Oliver Bennett'));
      await tester.pumpAndSettle();

      expect(find.text('This device can’t make phone calls.'), findsOneWidget);
      verifyNever(() => launcher.launchInApp(any()));
    });
  });

  group('WhatsApp', () {
    Future<void> openComposerForOliver(WidgetTester tester) async {
      await pumpApp(tester);
      await search(tester, 'oliver');
      await tester.tap(find.byTooltip('WhatsApp Oliver Bennett'));
      await tester.pumpAndSettle();
    }

    testWidgets('composer prefills WhatsApp but never sends', (tester) async {
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
      await openComposerForOliver(tester);

      expect(find.text('Message Oliver Bennett'), findsOneWidget);
      expect(find.text('Continue to WhatsApp'), findsOneWidget);
      verifyNever(() => launcher.launchInApp(any()));

      await tester.tap(find.text('Hi Oliver! 👋'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('composer-field')),
        'See you at 5?',
      );
      await tester.tap(find.text('Continue to WhatsApp'));
      await tester.pumpAndSettle();

      verify(
        () => launcher.launchInApp(
          Uri.parse('https://wa.me/447400123456?text=See%20you%20at%205%3F'),
        ),
      ).called(1);
      expect(
        find.text('WhatsApp opened. Review and send your message there.'),
        findsOneWidget,
      );
      expect(find.textContaining('sent'), findsNothing);
    });

    testWidgets('templates fill the message field', (tester) async {
      await openComposerForOliver(tester);
      await tester.tap(find.text('Hi Oliver! 👋'));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('composer-field')),
      );
      expect(field.controller!.text, 'Hi Oliver! 👋');
    });

    testWidgets('dismissing the composer does nothing', (tester) async {
      await openComposerForOliver(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      verifyZeroInteractions(launcher);
    });

    testWidgets('not installed offers WhatsApp Web', (tester) async {
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => false);
      when(() => launcher.launchInBrowser(any())).thenAnswer((_) async => true);
      await openComposerForOliver(tester);

      await tester.tap(find.text('Continue to WhatsApp'));
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp isn’t available'), findsOneWidget);

      await tester.tap(find.text('Open WhatsApp Web'));
      await tester.pumpAndSettle();
      verify(
        () => launcher.launchInBrowser(Uri.parse('https://wa.me/447400123456')),
      ).called(1);
      expect(find.text('Opened WhatsApp in your browser.'), findsOneWidget);
    });

    testWidgets('numbers without a country code are rejected', (tester) async {
      await pumpApp(tester);
      await tester.scrollUntilVisible(
        find.text('Unknown'),
        200,
        scrollable: mainScrollable,
      );
      await tester.tap(find.text('Unknown'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('WhatsApp Mystery Number'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('WhatsApp needs a number with a country code'),
        findsOneWidget,
      );
      verifyZeroInteractions(launcher);
    });
  });

  group('SMS', () {
    testWidgets('details: pick a number, compose, open Messages', (
      tester,
    ) async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
      await pumpApp(tester);
      await search(tester, 'emily');
      await tester.tap(find.text('Emily Johnson'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details-sms')));
      await tester.pumpAndSettle();
      expect(find.text('Text Emily Johnson'), findsOneWidget);
      await tester.tap(find.text('+44 7400 222333').last);
      await tester.pumpAndSettle();

      expect(find.text('Continue to Messages'), findsOneWidget);
      verifyNever(() => launcher.launchInApp(any()));
      await tester.enterText(
        find.byKey(const Key('composer-field')),
        'Call you later?',
      );
      await tester.tap(find.text('Continue to Messages'));
      await tester.pumpAndSettle();

      verify(
        () => launcher.launchInApp(
          Uri.parse('sms:+447400222333?body=Call%20you%20later%3F'),
        ),
      ).called(1);
      expect(
        find.text('Messages opened. Review and send your message there.'),
        findsOneWidget,
      );
    });

    testWidgets('tile: reports devices that cannot text', (tester) async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => false);
      await pumpApp(tester);
      await search(tester, 'oliver');
      await tester.tap(find.byTooltip('SMS Oliver Bennett'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hi Oliver! 👋'));
      await tester.tap(find.text('Continue to Messages'));
      await tester.pumpAndSettle();

      expect(
        find.text('This device can’t send text messages.'),
        findsOneWidget,
      );
      verifyNever(() => launcher.launchInApp(any()));
    });

    testWidgets('works for local numbers WhatsApp cannot use', (tester) async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
      await pumpApp(
        tester,
        repository: FakeContactsRepository(
          contacts: [
            contact('1', 'Omar Haddad', ['050 765 4321']),
          ],
        ),
      );
      await tester.tap(find.text('Unknown').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('WhatsApp Omar Haddad'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('WhatsApp needs a number with a country code'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('SMS Omar Haddad'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('composer-field')), 'Hi');
      await tester.tap(find.text('Continue to Messages'));
      await tester.pumpAndSettle();
      verify(
        () => launcher.launchInApp(Uri.parse('sms:0507654321?body=Hi')),
      ).called(1);
    });

    testWidgets('narrow phones keep SMS on the contact card only', (
      tester,
    ) async {
      await pumpApp(tester);
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      await tester.pumpAndSettle();
      await search(tester, 'oliver');
      expect(find.byTooltip('SMS Oliver Bennett'), findsNothing);
      expect(find.byTooltip('WhatsApp Oliver Bennett'), findsOneWidget);
    });
  });

  group('find country', () {
    Future<void> openCountrySearch(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('find-country')));
      await tester.pumpAndSettle();
      expect(find.text('Find a country'), findsOneWidget);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(SearchQueryController.debounce);
      await tester.pumpAndSettle();
    }

    testWidgets('lists all countries plus Unknown initially', (tester) async {
      await openCountrySearch(tester);
      for (final name in ['United Kingdom', 'United States', 'India']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('filters by name, ISO code and dialing code', (tester) async {
      await openCountrySearch(tester);

      await type(tester, 'ind');
      expect(find.text('India'), findsOneWidget);
      expect(find.text('United Kingdom'), findsNothing);
      expect(find.text('Unknown'), findsNothing);

      await type(tester, 'ae');
      expect(find.text('United Arab Emirates'), findsOneWidget);
      expect(find.text('India'), findsNothing);

      await type(tester, '+44');
      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('United States'), findsNothing);

      await type(tester, 'unknown');
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('shows an empty state for no match', (tester) async {
      await openCountrySearch(tester);
      await type(tester, 'atlantis');
      expect(find.text('No matching country'), findsOneWidget);
    });

    testWidgets('selecting a result opens that country', (tester) async {
      await openCountrySearch(tester);
      await type(tester, 'states');
      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();
      expect(find.text('+1  ·  US'), findsOneWidget);
      expect(find.text('James Miller'), findsOneWidget);
    });
  });

  testWidgets('settings change theme and region', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Settings').first)).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('Don’t assume a region'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
