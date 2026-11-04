import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/export/data/file_sharer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

class FakeFileSharer implements FileSharer {
  FakeFileSharer({this.shared = true, this.error});

  final bool shared;
  final Exception? error;
  final calls = <({String fileName, String contents, String mimeType})>[];

  @override
  Future<bool> shareText({
    required String fileName,
    required String contents,
    required String mimeType,
    Rect? origin,
  }) async {
    calls.add((fileName: fileName, contents: contents, mimeType: mimeType));
    if (error != null) throw error!;
    return shared;
  }
}

void main() {
  Future<void> selectInUk(WidgetTester tester, FakeFileSharer sharer) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await testOverrides(repository: FakeContactsRepository()),
          fileSharerProvider.overrideWithValue(sharer),
        ],
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-GB')));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Oliver Bennett'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amelia Clarke'));
    await tester.pumpAndSettle();
  }

  testWidgets('exports the selected contacts’ numbers as CSV', (tester) async {
    final sharer = FakeFileSharer();
    await selectInUk(tester, sharer);

    await tester.tap(find.byKey(const Key('export-selected')));
    await tester.pumpAndSettle();

    final call = sharer.calls.single;
    expect(call.mimeType, 'text/csv');
    expect(call.fileName, startsWith('Contacts Organizer - United Kingdom - '));
    expect(call.fileName, endsWith('.csv'));
    final rows = call.contents.split('\r\n')..removeLast();
    expect(rows, hasLength(4)); // header + Amelia ×2 + Oliver
    expect(rows[1], startsWith('Amelia,Clarke,'));
    expect(rows[3], startsWith('Oliver,Bennett,'));
    expect(find.text('Exported 3 numbers to CSV.'), findsOneWidget);
  });

  testWidgets('dismissing the share sheet shows nothing', (tester) async {
    final sharer = FakeFileSharer(shared: false);
    await selectInUk(tester, sharer);

    await tester.tap(find.byKey(const Key('export-selected')));
    await tester.pumpAndSettle();

    expect(sharer.calls, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports a failed export', (tester) async {
    await selectInUk(tester, FakeFileSharer(error: Exception('disk full')));

    await tester.tap(find.byKey(const Key('export-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t export.'), findsOneWidget);
  });
}
