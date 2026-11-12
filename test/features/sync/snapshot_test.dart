import 'dart:convert';

import 'package:country_contacts/features/crm/data/activity_repository.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/data/crm_repository.dart';
import 'package:country_contacts/features/sync/domain/backup_archive.dart';
import 'package:country_contacts/features/sync/domain/snapshot.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One simulated device with its own database and clock.
class Device {
  Device(this.id) : db = CrmDatabase(NativeDatabase.memory());

  final String id;
  final CrmDatabase db;
  var now = DateTime.utc(2026, 11, 12, 9);

  late final crm = CrmRepository(db, clock: () => now);
  late final activities = ActivityRepository(db, clock: () => now);

  Future<Map<String, dynamic>> snapshot() async =>
      jsonDecode(jsonEncode(await exportSnapshot(db, deviceId: id, now: now)))
          as Map<String, dynamic>;

  Future<List<String>> leadNames() async => [
    for (final p in await crm.watchParties(PartyKind.lead).first) p.name,
  ];
}

void main() {
  late Device phone;
  late Device ipad;

  setUp(() {
    phone = Device('phone');
    ipad = Device('ipad');
  });
  tearDown(() async {
    await phone.db.close();
    await ipad.db.close();
  });

  Future<String> addLead(Device d, String name) => d.crm.createParty(
    PartiesCompanion.insert(kind: PartyKind.lead, name: name),
  );

  test('records added on one device appear on the other', () async {
    await addLead(phone, 'Sara');
    await addLead(ipad, 'Omar');

    await mergeSnapshot(ipad.db, await phone.snapshot());
    await mergeSnapshot(phone.db, await ipad.snapshot());

    expect(await phone.leadNames(), ['Omar', 'Sara']);
    expect(await ipad.leadNames(), ['Omar', 'Sara']);
  });

  test('the most recent edit wins', () async {
    final id = await addLead(phone, 'Sara');
    await mergeSnapshot(ipad.db, await phone.snapshot());

    ipad.now = DateTime.utc(2026, 11, 12, 10);
    await ipad.crm.updateParty(
      id,
      const PartiesCompanion(name: Value('Sara K')),
    );
    phone.now = DateTime.utc(2026, 11, 12, 9, 30); // older edit
    await phone.crm.updateParty(
      id,
      const PartiesCompanion(name: Value('Sara (old)')),
    );

    await mergeSnapshot(phone.db, await ipad.snapshot());
    await mergeSnapshot(ipad.db, await phone.snapshot());
    expect(await phone.leadNames(), ['Sara K']);
    expect(await ipad.leadNames(), ['Sara K']);
  });

  test('deletions sync, and merging twice changes nothing', () async {
    final id = await addLead(phone, 'Sara');
    await mergeSnapshot(ipad.db, await phone.snapshot());
    ipad.now = DateTime.utc(2026, 11, 13);
    await ipad.crm.deleteParty(id);

    final first = await mergeSnapshot(phone.db, await ipad.snapshot());
    final again = await mergeSnapshot(phone.db, await ipad.snapshot());
    expect(await phone.leadNames(), isEmpty);
    expect(first.changed, greaterThan(0));
    expect(again.changed, 0);
  });

  test('custom statuses, deals and activities travel too', () async {
    final warm = await phone.crm.addStatus('Warm', 0xFFFFA000);
    final id = await phone.crm.createParty(
      PartiesCompanion.insert(
        kind: PartyKind.client,
        name: 'Bilal',
        statusId: Value(warm),
      ),
    );
    await phone.crm.createDeal(
      DealsCompanion.insert(
        partyId: id,
        type: DealType.bought,
        item: 'Villa',
        date: DateTime.utc(2026, 1, 1),
      ),
    );
    await phone.activities.createActivity(
      ActivitiesCompanion.insert(
        type: ActivityType.lunch,
        priority: ActivityPriority.high,
        title: 'Lunch with Bilal',
        partyId: Value(id),
      ),
      attachments: ['menu.jpg'],
    );

    await mergeSnapshot(ipad.db, await phone.snapshot());
    expect(
      (await ipad.crm.watchStatuses().first).map((s) => s.name),
      contains('Warm'),
    );
    expect((await ipad.crm.watchDeals(id).first).single.item, 'Villa');
    final [lunch] = await ipad.activities.watchActivities().first;
    expect(lunch.title, 'Lunch with Bilal');
    expect(await ipad.activities.watchAttachmentCounts().first, {lunch.id: 1});
    expect(snapshotAttachmentFiles(await phone.snapshot()), {'menu.jpg'});
  });

  test('restoring a backup replaces everything', () async {
    await addLead(phone, 'Sara');
    final backup = await phone.snapshot();
    await addLead(phone, 'Added after the backup');

    await replaceWithSnapshot(phone.db, backup);
    expect(await phone.leadNames(), ['Sara']);
    expect((await phone.crm.watchStatuses().first).map((s) => s.name), [
      'Cold',
      'Hot',
    ]);
  });

  test('a backup from a newer app version is refused', () async {
    final snap = await phone.snapshot();
    snap['schema'] = 99;
    expect(
      () => mergeSnapshot(ipad.db, snap),
      throwsA(isA<SnapshotTooNewException>()),
    );
  });

  test('backup files round-trip data and images', () async {
    await addLead(phone, 'Sara');
    final bytes = encodeBackup(
      BackupContents(
        snapshot: await phone.snapshot(),
        attachments: {
          'a.jpg': Uint8List.fromList([1, 2, 3]),
        },
      ),
    );
    final back = decodeBackup(bytes);
    expect(back.attachments['a.jpg'], [1, 2, 3]);
    await replaceWithSnapshot(ipad.db, back.snapshot);
    expect(await ipad.leadNames(), ['Sara']);

    expect(
      () => decodeBackup(Uint8List.fromList(utf8.encode('nope'))),
      throwsA(isA<InvalidBackupException>()),
    );
  });
}
