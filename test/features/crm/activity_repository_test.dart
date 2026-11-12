import 'dart:io';

import 'package:country_contacts/features/crm/data/activity_repository.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/data/crm_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrmDatabase db;
  late ActivityRepository repo;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 12, 9);
    db = CrmDatabase(NativeDatabase.memory());
    repo = ActivityRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<String> activity(
    String title, {
    DateTime? due,
    String? partyId,
    ActivityType type = ActivityType.call,
  }) => repo.createActivity(
    ActivitiesCompanion.insert(
      type: type,
      priority: ActivityPriority.medium,
      title: title,
      dueAt: Value(due),
      partyId: Value(partyId),
    ),
  );

  test('open activities by due date, undated next, done last', () async {
    final done = await activity('Done', due: DateTime(2026, 11, 1));
    await activity('Someday');
    await activity('Friday', due: DateTime(2026, 11, 14));
    await activity('Tomorrow', due: DateTime(2026, 11, 13));
    await repo.setDone(done, done: true);

    expect((await repo.watchActivities().first).map((a) => a.title), [
      'Tomorrow',
      'Friday',
      'Someday',
      'Done',
    ]);
  });

  test('marking done stamps the time and can be undone', () async {
    final id = await activity('Call back');
    await repo.setDone(id, done: true);
    expect((await repo.watchActivity(id).first)!.completedAt, now);
    await repo.setDone(id, done: false);
    expect((await repo.watchActivity(id).first)!.completedAt, isNull);
  });

  test('activities can be listed for one lead or client', () async {
    final party = await CrmRepository(
      db,
    ).createParty(PartiesCompanion.insert(kind: PartyKind.lead, name: 'Sara'));
    await activity('With Sara', partyId: party);
    await activity('Someone else');

    expect(
      (await repo.watchActivities(partyId: party).first).map((a) => a.title),
      ['With Sara'],
    );
  });

  test('attachments are counted, and deleted with their activity', () async {
    final id = await repo.createActivity(
      ActivitiesCompanion.insert(
        type: ActivityType.meeting,
        priority: ActivityPriority.high,
        title: 'Viewing',
      ),
      attachments: ['a.jpg', 'b.jpg'],
    );
    expect(await repo.watchAttachmentCounts().first, {id: 2});

    final files = await repo.deleteActivity(id);
    expect(files, unorderedEquals(['a.jpg', 'b.jpg']));
    expect(await repo.watchActivity(id).first, isNull);
    expect(await repo.watchAttachmentCounts().first, isEmpty);
  });

  test('upgrading a version 1 database adds activities', () async {
    final dir = await Directory.systemTemp.createTemp('crm');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    // Make a database shaped like version 1 (no activity tables).
    final v1 = CrmDatabase(NativeDatabase(file));
    await CrmRepository(
      v1,
    ).createParty(PartiesCompanion.insert(kind: PartyKind.lead, name: 'Kept'));
    await v1.customStatement('DROP TABLE activity_attachments');
    await v1.customStatement('DROP TABLE activities');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final v2 = CrmDatabase(NativeDatabase(file));
    addTearDown(v2.close);
    final upgraded = ActivityRepository(v2);
    await upgraded.createActivity(
      ActivitiesCompanion.insert(
        type: ActivityType.task,
        priority: ActivityPriority.low,
        title: 'Works',
      ),
    );
    expect((await upgraded.watchActivities().first).single.title, 'Works');
    expect(
      (await CrmRepository(v2).watchParties(PartyKind.lead).first).single.name,
      'Kept',
    );
  });
}
