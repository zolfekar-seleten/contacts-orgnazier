import 'dart:convert';
import 'dart:typed_data';

import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/import/data/file_source.dart';
import 'package:country_contacts/features/import/domain/column_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

class FakeSpreadsheet implements SpreadsheetSource {
  FakeSpreadsheet(this.name, this.text);

  final String name;
  final String text;

  @override
  Future<PickedFile?> pick() async =>
      (name: name, bytes: Uint8List.fromList(utf8.encode(text)));
}

const _csv =
    'Client Name,Mobile No.,Nationality,Lead Source,Status,Notes\n'
    'Sara Khan,+971 50 123 4567,Indian,Instagram,Hot,x\n'
    'Omar Haddad,0501112222,Jordanian,Referral,Viewing,\n'
    'Sara Duplicate,00971501234567,,,,\n'
    ',0503334444,,,,\n';

void importTest(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      // Unmount so drift's stream clean-up timer fires before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

void main() {
  Future<void> pumpApp(WidgetTester tester, {String csv = _csv}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await testOverrides(
            repository: FakeContactsRepository(),
            deviceRegion: 'AE',
          ),
          spreadsheetSourceProvider.overrideWithValue(
            FakeSpreadsheet('leads.csv', csv),
          ),
        ],
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> openImport(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-leads')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-lead')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-pick')));
    await settle(tester);
  }

  ImportField mapping(WidgetTester tester, int column) => tester
      .widget<DropdownButton<ImportField>>(find.byKey(ValueKey('map-$column')))
      .value!;

  String stat(WidgetTester tester, String key) => tester
      .widget<Text>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
            )
            .first,
      )
      .data!;

  importTest('columns are matched and the preview counts rows', (tester) async {
    await pumpApp(tester);
    await openImport(tester);

    expect(find.text('leads.csv'), findsOneWidget);
    expect(find.text('4 rows'), findsOneWidget);
    expect(mapping(tester, 0), ImportField.name);
    expect(mapping(tester, 1), ImportField.mobile);
    expect(mapping(tester, 2), ImportField.nationality);
    expect(mapping(tester, 3), ImportField.source);
    expect(mapping(tester, 4), ImportField.status);
    expect(mapping(tester, 5), ImportField.ignore);

    await tester.scrollUntilVisible(
      find.byKey(const Key('import-ready')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(stat(tester, 'import-ready'), '2');
    expect(stat(tester, 'import-duplicates'), '1');
    expect(stat(tester, 'import-noname'), '1');
    expect(find.text('New statuses will be added: Viewing'), findsOneWidget);
    expect(find.text('Import 2 leads'), findsOneWidget);
  });

  importTest('importing adds the leads with their statuses', (tester) async {
    await pumpApp(tester);
    await openImport(tester);
    await tester.tap(find.byKey(const Key('import-run')));
    await settle(tester);

    expect(find.text('Imported 2 leads'), findsOneWidget);
    expect(find.textContaining('1 skipped as duplicates.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.text('Sara Khan'), findsOneWidget);
    expect(find.text('Omar Haddad'), findsOneWidget);
    // Local number used the default region (UAE).
    expect(find.text('+971 50 111 2222'), findsOneWidget);
    expect(find.text('Hot 1'), findsOneWidget);
    expect(find.text('Viewing 1'), findsOneWidget);

    // Importing again skips everyone already saved.
    await tester.tap(find.byKey(const Key('import-lead')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-pick')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('import-ready')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(stat(tester, 'import-ready'), '0');
    expect(stat(tester, 'import-duplicates'), '3');
  });

  importTest('a column can be remapped by hand', (tester) async {
    await pumpApp(tester, csv: 'Who,Tel,Comment\nSara,0501234567,Instagram\n');
    await openImport(tester);
    // "Who" is the name; the free-text comment isn't imported by default.
    expect(mapping(tester, 0), ImportField.name);
    expect(mapping(tester, 2), ImportField.ignore);

    await tester.tap(find.byKey(const ValueKey('map-2')));
    await settle(tester);
    await tester.tap(find.text('Source').last);
    await settle(tester);
    expect(mapping(tester, 2), ImportField.source);
  });

  importTest('old .xls files explain what to do', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await testOverrides(repository: FakeContactsRepository()),
          spreadsheetSourceProvider.overrideWithValue(
            FakeSpreadsheet('old.xls', 'x'),
          ),
        ],
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await openImport(tester);
    expect(
      find.textContaining('Old .xls files aren’t supported'),
      findsOneWidget,
    );
  });
}
