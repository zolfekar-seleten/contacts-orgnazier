import 'dart:io';

import 'package:country_contacts/app.dart';
import 'package:country_contacts/features/crm/data/attachment_store.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/presentation/activity_widgets.dart';
import 'package:country_contacts/features/crm/presentation/crm_providers.dart';
import 'package:country_contacts/features/shell/root_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../support/fixtures.dart';

/// Returns one small image from the library and none from the camera.
class FakeImageSource implements ImageSourceGateway {
  FakeImageSource(this.image);

  final File image;

  @override
  Future<List<XFile>> pickFromLibrary() async => [XFile(image.path)];

  @override
  Future<XFile?> takePhoto() async => null;
}

void activityTest(
  String description,
  Future<void> Function(WidgetTester) body,
) => testWidgets(description, (tester) async {
  await body(tester);
  // Unmount so drift's stream clean-up timer fires before the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
});

void main() {
  late File image;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('img');
    // A 1×1 transparent PNG.
    image = File('${dir.path}/photo.png')
      ..writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, //
        0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
        0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
        0x82,
      ]);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await testOverrides(repository: FakeContactsRepository()),
          imageSourceProvider.overrideWithValue(FakeImageSource(image)),
        ],
        child: const CountryContactsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drift and file work run off the fake clock, so let real time pass.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.byKey(ValueKey('tab-$tab')));
    await settle(tester);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(RootShell)));

  Future<String> addLead(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => container(tester)
            .read(crmRepositoryProvider)
            .createParty(
              PartiesCompanion.insert(
                kind: PartyKind.lead,
                name: name,
                dialCode: const Value('44'),
                mobile: const Value('7400123456'),
              ),
            ),
      ))!;

  activityTest('empty state, then a meeting with a lead', (tester) async {
    await pumpApp(tester);
    await addLead(tester, 'Sara Khan');
    await openTab(tester, 'activities');
    expect(find.text('No activities yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-activity')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('type-meeting')));
    await tester.tap(find.text('High'));
    await tester.tap(find.byKey(const Key('activity-with')));
    await settle(tester);
    await tester.tap(find.text('Sara Khan'));
    await settle(tester);
    // Without a title, one is made from the type and person.
    expect(find.text('Meeting with Sara Khan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-save')));
    await settle(tester);
    expect(find.text('NO DATE'), findsOneWidget);
    expect(find.text('Meeting with Sara Khan'), findsOneWidget);
    expect(find.text('Sara Khan'), findsOneWidget); // who, on the tile
  });

  activityTest('a styled note and an image are saved', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'activities');
    await tester.tap(find.byKey(const Key('add-activity')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('activity-title')), 'Viewing');

    // Type into the note, select it all, then bold it with the toolbar.
    final editor = tester.state<QuillEditorState>(find.byType(QuillEditor));
    editor.controller
      ..replaceText(0, 0, 'Bring the floor plans', null)
      ..updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 21),
        ChangeSource.local,
      );
    await tester.pump();
    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('add-photos')));
    await tester.tap(find.byKey(const Key('add-photos')));
    // Copying the photo is real file work; give it real time.
    for (var i = 0; i < 30; i++) {
      await settle(tester);
      if (find.byTooltip('Remove image').evaluate().isNotEmpty) break;
    }
    expect(find.byTooltip('Remove image'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-save')));
    await settle(tester);
    expect(find.text('Viewing'), findsOneWidget);
    expect(find.text('Bring the floor plans'), findsOneWidget); // preview
    expect(
      find.descendant(
        of: find.byType(ActivityTile),
        matching: find.byIcon(Icons.image_outlined),
      ),
      findsOneWidget,
    );

    final saved = (await tester.runAsync(
      () => container(
        tester,
      ).read(activityRepositoryProvider).watchActivities().first,
    ))!.single;
    expect(saved.noteJson, contains('"bold":true'));

    // Reopening shows the note (drawn as rich text) and the image.
    await tester.tap(find.text('Viewing'));
    await settle(tester);
    expect(
      find.textContaining('Bring the floor plans', findRichText: true),
      findsWidgets,
    );
    expect(find.byTooltip('Remove image'), findsOneWidget);
  });

  activityTest('ticking an activity moves it to Done', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'activities');
    await tester.tap(find.byKey(const Key('add-activity')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('type-task')));
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Send offer',
    );
    await tester.tap(find.byKey(const Key('activity-save')));
    await settle(tester);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(find.text('Send offer'), findsNothing);
    expect(find.text('All clear'), findsOneWidget);

    await tester.tap(find.byKey(const Key('show-done')));
    await settle(tester);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('Send offer'), findsOneWidget);
  });

  activityTest('a lead’s page lists and adds its activities', (tester) async {
    await pumpApp(tester);
    await addLead(tester, 'Sara Khan');
    await openTab(tester, 'leads');
    await tester.tap(find.text('Sara Khan'));
    await settle(tester);
    expect(find.text('No calls, meetings or tasks yet.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-party-activity')));
    await tester.tap(find.byKey(const Key('add-party-activity')));
    await settle(tester);
    // "With" is already Sara.
    expect(find.text('Sara Khan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-save')));
    await settle(tester);

    expect(find.text('Call with Sara Khan'), findsOneWidget);
  });

  activityTest('filter by type and delete', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'activities');
    for (final (type, title) in [
      ('email', 'Send brochure'),
      ('lunch', 'Lunch'),
    ]) {
      await tester.tap(find.byKey(const Key('add-activity')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('type-$type')));
      await tester.enterText(find.byKey(const Key('activity-title')), title);
      await tester.tap(find.byKey(const Key('activity-save')));
      await settle(tester);
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('activity-filter-email')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-filter-email')));
    await settle(tester);
    // "Lunch" is also a filter chip, so look only at the list.
    Finder listed(String title) => find.descendant(
      of: find.byType(ActivityTile),
      matching: find.text(title),
    );
    expect(listed('Send brochure'), findsOneWidget);
    expect(listed('Lunch'), findsNothing);

    await tester.tap(find.text('Send brochure'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('activity-delete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('activity-delete-confirm')));
    await settle(tester);
    expect(find.text('Send brochure'), findsNothing);
  });
}
