import 'dart:io';

import 'package:country_contacts/app.dart';
import 'package:country_contacts/core/clock.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/presentation/crm_providers.dart';
import 'package:country_contacts/features/settings/presentation/settings_providers.dart';
import 'package:country_contacts/features/shell/root_shell.dart';
import 'package:country_contacts/features/sync/data/cloud_service.dart';
import 'package:country_contacts/features/sync/data/icloud_files.dart';
import 'package:country_contacts/features/sync/presentation/cloud_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void cloudTest(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      // Unmount so drift's stream clean-up timer fires before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

void main() {
  late FolderCloudFiles cloud;

  Future<void> pumpApp(WidgetTester tester, {bool available = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    cloud = FolderCloudFiles(
      (await tester.runAsync(() => Directory.systemTemp.createTemp('icloud')))!,
      available: available,
    );
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('tmp'),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await testOverrides(repository: FakeContactsRepository()),
          cloudFilesProvider.overrideWithValue(cloud),
          cloudServiceProvider.overrideWith(
            (ref) => CloudService(
              db: ref.watch(crmDatabaseProvider),
              files: cloud,
              attachments: ref.watch(attachmentStoreProvider),
              prefs: ref.watch(sharedPreferencesProvider),
              tempDir: () async => temp,
              clock: ref.watch(clockProvider),
            ),
          ),
        ],
        child: const CountryContactsApp(),
      ),
    );
    await settle(tester);
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    // The shell is offstage while Settings is pushed on top.
    tester.element(find.byType(RootShell, skipOffstage: false)),
  );

  Future<void> openICloud(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-icloud')));
    await settle(tester);
  }

  /// Lists the stand-in iCloud folder directly (works even when "signed
  /// out").
  Future<List<String>> files(WidgetTester tester, String dir) async =>
      (await tester.runAsync(() async {
        final d = Directory('${cloud.root.path}/$dir');
        if (!await d.exists()) return <String>[];
        return [
          await for (final e in d.list())
            if (e is File) e.uri.pathSegments.last,
        ];
      }))!;

  cloudTest('on launch it syncs and makes the first backup', (tester) async {
    await pumpApp(tester);
    for (var i = 0; i < 40; i++) {
      if ((await files(tester, CloudService.backupsDir)).isNotEmpty) break;
      await settle(tester);
    }
    expect(await files(tester, CloudService.syncDir), [startsWith('device-')]);
    expect(await files(tester, CloudService.backupsDir), [
      'Contacts Organizer 2026-06-15 1200.zip',
    ]);
  });

  cloudTest('back up now, then restore', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => container(tester)
          .read(crmRepositoryProvider)
          .createParty(
            PartiesCompanion.insert(kind: PartyKind.lead, name: 'Sara'),
          ),
    );
    await openICloud(tester);
    expect(find.text('iCloud is on'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cloud-backup-now')));
    await settle(tester);
    expect(find.text('Backed up to iCloud.'), findsOneWidget);

    // Something added after the backup goes away on restore.
    await tester.runAsync(
      () => container(tester)
          .read(crmRepositoryProvider)
          .createParty(
            PartiesCompanion.insert(kind: PartyKind.lead, name: 'Later'),
          ),
    );
    await tester.tap(find.byKey(const Key('cloud-restore')));
    await settle(tester);
    await tester.tap(find.byType(ListTile).last); // newest is first; pick any
    await settle(tester);
    await tester.tap(find.byKey(const Key('restore-confirm')));
    await settle(tester);
    expect(find.text('Backup restored.'), findsOneWidget);

    final leads = (await tester.runAsync(
      () => container(
        tester,
      ).read(crmRepositoryProvider).watchParties(PartyKind.lead).first,
    ))!;
    expect(leads.map((p) => p.name), ['Sara']);
  });

  cloudTest('without iCloud the screen explains and disables actions', (
    tester,
  ) async {
    await pumpApp(tester, available: false);
    await openICloud(tester);
    expect(find.text('Available on iPhone'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('cloud-backup-now')))
          .onPressed,
      isNull,
    );
    expect(await files(tester, CloudService.backupsDir), isEmpty);
  });
}

/// File and database work run off the test clock, so give it real time
/// until nothing is in progress (a spinner would never let the UI settle).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i > 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}
