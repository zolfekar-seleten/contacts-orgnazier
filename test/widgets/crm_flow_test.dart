import 'package:country_contacts/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// Runs [body], then unmounts the app so drift's stream clean-up timer
/// (it waits briefly after the last listener) fires before the test ends.
void crmTest(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await testOverrides(repository: FakeContactsRepository()),
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drift runs queries off the test clock, so let real time pass.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.byKey(ValueKey('tab-$tab')));
    await settle(tester);
  }

  Future<void> addLead(
    WidgetTester tester, {
    required String name,
    String mobile = '07400 123456',
    String? status,
  }) async {
    await tester.tap(find.byKey(const Key('add-lead')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('party-name')), name);
    await tester.enterText(find.byKey(const Key('party-mobile')), mobile);
    if (status != null) {
      await tester.ensureVisible(find.byKey(ValueKey('form-status-$status')));
      await tester.tap(find.byKey(ValueKey('form-status-$status')));
    }
    await tester.tap(find.byKey(const Key('party-save')));
    await settle(tester);
  }

  crmTest('tabs: Contacts first, then Leads and Clients', (tester) async {
    await pumpApp(tester);
    expect(find.text('Contacts Organizer'), findsWidgets);

    await openTab(tester, 'leads');
    expect(find.text('No leads yet'), findsOneWidget);
    expect(find.text('All 0'), findsOneWidget);

    await openTab(tester, 'clients');
    expect(find.text('No clients yet'), findsOneWidget);
  });

  crmTest('add a lead with a status, then filter by it', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await addLead(tester, name: 'Sara Khan', status: 'Hot');
    await addLead(tester, name: 'Omar Haddad', mobile: '+971 50 123 4567');

    expect(find.text('Sara Khan'), findsOneWidget);
    // The UK default calling code is applied and the trunk 0 dropped.
    expect(find.text('+44 7400 123456'), findsOneWidget);
    // A pasted international number brings its own code.
    expect(find.text('+971 50 123 4567'), findsOneWidget);
    expect(find.text('All 2'), findsOneWidget);
    expect(find.text('Hot 1'), findsOneWidget);
    expect(find.text('Cold 1'), findsOneWidget); // new leads default to Cold

    await tester.tap(find.byKey(const ValueKey('status-Hot')));
    await settle(tester);
    expect(find.text('Sara Khan'), findsOneWidget);
    expect(find.text('Omar Haddad'), findsNothing);
  });

  crmTest('convert a lead to a client and record a purchase', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await addLead(tester, name: 'Sara Khan');

    await tester.tap(find.text('Sara Khan'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('convert-client')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('convert-confirm')));
    await settle(tester);
    expect(find.text('Sara Khan is now a client.'), findsOneWidget);
    expect(find.textContaining('was a lead'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-deal')));
    await tester.tap(find.byKey(const Key('add-deal')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('deal-item')), '2BR apartment');
    await tester.enterText(
      find.byKey(const Key('deal-location')),
      'Dubai Marina',
    );
    await tester.tap(find.byKey(const Key('deal-save')));
    await settle(tester);
    expect(find.text('2BR apartment'), findsOneWidget);
    expect(find.textContaining('Bought · '), findsOneWidget);
    expect(find.textContaining('Dubai Marina'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('No leads yet'), findsOneWidget);
    await openTab(tester, 'clients');
    expect(find.text('Sara Khan'), findsOneWidget);
  });

  crmTest('change a lead’s status from its details', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await addLead(tester, name: 'Sara Khan');
    await tester.tap(find.text('Sara Khan'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('detail-status')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('pick-status-Hot')));
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-status')),
        matching: find.text('Hot'),
      ),
      findsOneWidget,
    );
  });

  crmTest('add a status, and delete one moving its leads', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await addLead(tester, name: 'Sara Khan', status: 'Hot');

    await tester.tap(find.byKey(const Key('manage-statuses')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-status')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('status-name')), 'Warm');
    await tester.tap(find.byKey(const Key('status-save')));
    await settle(tester);
    expect(find.text('Warm'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Hot'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('move-to-Warm')));
    await settle(tester);
    expect(find.byTooltip('Delete Hot'), findsNothing);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Warm 1'), findsOneWidget);
  });

  crmTest('delete a lead', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await addLead(tester, name: 'Sara Khan');
    await tester.tap(find.text('Sara Khan'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('party-more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('party-delete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await settle(tester);
    expect(find.text('No leads yet'), findsOneWidget);
  });

  crmTest('empty Leads offers sample data', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await tester.tap(find.text('Try with sample data'));
    for (var i = 0; i < 6; i++) {
      await settle(tester);
    }
    expect(
      find.text('Added 40 leads, 18 clients and 30 activities.'),
      findsOneWidget,
    );
    expect(find.text('All 40'), findsOneWidget);
    expect(find.text('No leads yet'), findsNothing);
  });

  crmTest('a name is required', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'leads');
    await tester.tap(find.byKey(const Key('add-lead')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('party-save')));
    await settle(tester);
    expect(find.text('Enter a name'), findsOneWidget);
  });
}
