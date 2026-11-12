import 'dart:io';

import 'package:country_contacts/features/crm/data/activity_repository.dart';
import 'package:country_contacts/features/crm/data/attachment_store.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/data/crm_repository.dart';
import 'package:country_contacts/features/sync/data/cloud_service.dart';
import 'package:country_contacts/features/sync/data/icloud_files.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device: its own database, images folder and settings, sharing one
/// "iCloud" folder with the others.
class Device {
  Device._(this.db, this.store, this.service, this.clock);

  final CrmDatabase db;
  final AttachmentStore store;
  final CloudService service;
  final TestClock clock;

  late final crm = CrmRepository(db, clock: clock.call);
  late final activities = ActivityRepository(db, clock: clock.call);

  static Future<Device> create(
    FolderCloudFiles cloud,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    // Each device needs its own prefs instance.
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final dir = await Directory.systemTemp.createTemp('device');
    final db = CrmDatabase(NativeDatabase.memory());
    final store = AttachmentStore(root: () async => dir);
    final clock = TestClock();
    return Device._(
      db,
      store,
      CloudService(
        db: db,
        files: cloud,
        attachments: store,
        prefs: _ScopedPrefs(p, '${dir.path}:'),
        tempDir: () async => dir,
        clock: clock.call,
      ),
      clock,
    );
  }

  Future<List<String>> leads() async => [
    for (final p in await crm.watchParties(PartyKind.lead).first) p.name,
  ];
}

class TestClock {
  var now = DateTime(2026, 11, 12, 9, 30);
  DateTime call() => now;
}

/// Gives each simulated device its own keys inside one prefs store.
class _ScopedPrefs implements SharedPreferences {
  _ScopedPrefs(this._p, this._prefix);
  final SharedPreferences _p;
  final String _prefix;

  @override
  String? getString(String key) => _p.getString('$_prefix$key');
  @override
  Future<bool> setString(String key, String value) =>
      _p.setString('$_prefix$key', value);
  @override
  int? getInt(String key) => _p.getInt('$_prefix$key');
  @override
  Future<bool> setInt(String key, int value) =>
      _p.setInt('$_prefix$key', value);
  @override
  bool? getBool(String key) => _p.getBool('$_prefix$key');
  @override
  Future<bool> setBool(String key, bool value) =>
      _p.setBool('$_prefix$key', value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FolderCloudFiles cloud;
  late Device phone;
  late Device ipad;

  setUp(() async {
    cloud = FolderCloudFiles(await Directory.systemTemp.createTemp('icloud'));
    phone = await Device.create(cloud, {});
    ipad = await Device.create(cloud, {});
  });
  tearDown(() async {
    await phone.db.close();
    await ipad.db.close();
  });

  Future<String> lead(Device d, String name) => d.crm.createParty(
    PartiesCompanion.insert(kind: PartyKind.lead, name: name),
  );

  group('backups', () {
    test('backup, change things, restore', () async {
      await lead(phone, 'Sara');
      final name = await phone.service.backupNow();
      expect(name, 'Contacts Organizer 2026-11-12 0930.zip');
      expect(phone.service.lastBackup, phone.clock.now);

      await lead(phone, 'After backup');
      await phone.service.restore(name);
      expect(await phone.leads(), ['Sara']);
    });

    test('a new device can restore another device’s backup', () async {
      await lead(phone, 'Sara');
      await phone.service.backupNow();
      final [backup] = await ipad.service.backups();
      await ipad.service.restore(backup.name);
      expect(await ipad.leads(), ['Sara']);
    });

    test('images are included in backups', () async {
      final image = await phone.store.file('photo.jpg');
      await image.writeAsBytes([7, 7, 7]);
      await phone.activities.createActivity(
        ActivitiesCompanion.insert(
          type: ActivityType.meeting,
          priority: ActivityPriority.medium,
          title: 'Viewing',
        ),
        attachments: ['photo.jpg'],
      );
      await phone.service.backupNow();

      final [backup] = await ipad.service.backups();
      await ipad.service.restore(backup.name);
      expect(await (await ipad.store.file('photo.jpg')).readAsBytes(), [
        7,
        7,
        7,
      ]);
    });

    test('daily: only when a day has passed, and only if enabled', () async {
      expect(await phone.service.backupIfDue(), isTrue);
      phone.clock.now = phone.clock.now.add(const Duration(hours: 5));
      expect(await phone.service.backupIfDue(), isFalse);
      phone.clock.now = phone.clock.now.add(const Duration(hours: 20));
      expect(await phone.service.backupIfDue(), isTrue);

      await phone.service.prefs.setBool(CloudService.backupEnabledKey, false);
      phone.clock.now = phone.clock.now.add(const Duration(days: 3));
      expect(await phone.service.backupIfDue(), isFalse);
    });

    test('keeps the latest 14 backups', () async {
      for (var i = 0; i < 16; i++) {
        phone.clock.now = DateTime(2026, 11, 1 + i, 8);
        await phone.service.backupNow();
      }
      final list = await phone.service.backups();
      expect(list, hasLength(14));
      expect(list.first.name, 'Contacts Organizer 2026-11-16 0800.zip');
      expect(list.last.name, 'Contacts Organizer 2026-11-03 0800.zip');
    });
  });

  group('sync', () {
    test('two devices end up with everything', () async {
      await lead(phone, 'Sara');
      await lead(ipad, 'Omar');

      await phone.service.syncNow(); // publishes Sara
      final r = await ipad.service.syncNow(); // takes Sara, publishes both
      await phone.service.syncNow(); // takes Omar

      expect(r.devices, 1);
      expect(await phone.leads(), ['Omar', 'Sara']);
      expect(await ipad.leads(), ['Omar', 'Sara']);
      expect(ipad.service.lastSync, ipad.clock.now);
    });

    test('edits and deletions follow the latest change', () async {
      final id = await lead(phone, 'Sara');
      await phone.service.syncNow();
      await ipad.service.syncNow();

      ipad.clock.now = DateTime(2026, 11, 12, 11);
      await ipad.crm.updateParty(
        id,
        const PartiesCompanion(name: Value('Sara Khan')),
      );
      await ipad.service.syncNow();
      await phone.service.syncNow();
      expect(await phone.leads(), ['Sara Khan']);

      phone.clock.now = DateTime(2026, 11, 12, 12);
      await phone.crm.deleteParty(id);
      await phone.service.syncNow();
      await ipad.service.syncNow();
      expect(await ipad.leads(), isEmpty);
    });

    test('images are shared between devices', () async {
      await (await phone.store.file('menu.jpg')).writeAsBytes([1, 2]);
      await phone.activities.createActivity(
        ActivitiesCompanion.insert(
          type: ActivityType.lunch,
          priority: ActivityPriority.low,
          title: 'Lunch',
        ),
        attachments: ['menu.jpg'],
      );
      await phone.service.syncNow();
      await ipad.service.syncNow();
      expect(await (await ipad.store.file('menu.jpg')).readAsBytes(), [1, 2]);
    });

    test('without iCloud, sync and backup fail clearly', () async {
      cloud.available = false;
      expect(
        () => phone.service.syncNow(),
        throwsA(isA<CloudUnavailableException>()),
      );
      expect(
        () => phone.service.backupNow(),
        throwsA(isA<CloudUnavailableException>()),
      );
    });
  });
}
