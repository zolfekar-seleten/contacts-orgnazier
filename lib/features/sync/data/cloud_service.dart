import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../crm/data/attachment_store.dart';
import '../../crm/data/crm_database.dart';
import '../domain/backup_archive.dart';
import '../domain/snapshot.dart';
import 'icloud_files.dart';

/// What a sync did.
class SyncResult {
  const SyncResult({required this.devices, required this.changed});

  /// Other devices whose data was merged.
  final int devices;

  /// Rows added or updated here.
  final int changed;
}

/// iCloud backups (daily, kept for two weeks) and sync between the user's
/// devices. Both go through the app's iCloud Drive container:
///
/// * `Documents/Backups/Contacts Organizer 2026-11-12 0930.zip` — visible in
///   the Files app under iCloud Drive › Contacts Organizer.
/// * `Sync/device-<id>.json` — one snapshot per device. Each device only
///   writes its own file and merges the others by last edit time, so two
///   devices never overwrite each other. Images go to `Sync/attachments/`.
class CloudService {
  CloudService({
    required this.db,
    required this.files,
    required this.attachments,
    required this.prefs,
    required this.tempDir,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final CrmDatabase db;
  final CloudFiles files;
  final AttachmentStore attachments;
  final SharedPreferences prefs;
  final Future<Directory> Function() tempDir;
  final DateTime Function() _now;

  static const backupsDir = 'Documents/Backups';
  static const syncDir = 'Sync';
  static const keepBackups = 14;

  static const _deviceKey = 'icloud_device_id';
  static const lastBackupKey = 'icloud_last_backup';
  static const lastSyncKey = 'icloud_last_sync';
  static const backupEnabledKey = 'icloud_backup_enabled';
  static const syncEnabledKey = 'icloud_sync_enabled';

  String get deviceId {
    final saved = prefs.getString(_deviceKey);
    if (saved != null) return saved;
    final id = const Uuid().v4();
    prefs.setString(_deviceKey, id);
    return id;
  }

  bool get backupEnabled => prefs.getBool(backupEnabledKey) ?? true;
  bool get syncEnabled => prefs.getBool(syncEnabledKey) ?? true;
  DateTime? get lastBackup => _time(lastBackupKey);
  DateTime? get lastSync => _time(lastSyncKey);

  DateTime? _time(String key) {
    final ms = prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<File> _temp(String name) async =>
      File('${(await tempDir()).path}/$name');

  // Backups ----------------------------------------------------------------

  /// Uploads a backup and returns its file name.
  Future<String> backupNow() async {
    final now = _now();
    final snapshot = await exportSnapshot(db, deviceId: deviceId, now: now);
    final images = <String, Uint8List>{};
    for (final name in snapshotAttachmentFiles(snapshot)) {
      final f = await attachments.file(name);
      if (await f.exists()) images[name] = await f.readAsBytes();
    }
    final bytes = encodeBackup(
      BackupContents(snapshot: snapshot, attachments: images),
    );
    final name = 'Contacts Organizer ${_stamp(now)}.zip';
    final local = await _temp(name);
    await local.writeAsBytes(bytes, flush: true);
    await files.upload(local.path, '$backupsDir/$name');
    await local.delete();
    await prefs.setInt(lastBackupKey, now.millisecondsSinceEpoch);
    await _pruneBackups();
    return name;
  }

  /// Backs up when enabled and the last backup is a day old or more.
  Future<bool> backupIfDue() async {
    if (!backupEnabled) return false;
    final last = lastBackup;
    if (last != null && _now().difference(last) < const Duration(hours: 24)) {
      return false;
    }
    await backupNow();
    return true;
  }

  /// Newest first.
  Future<List<CloudFile>> backups() async {
    final list = [
      for (final f in await files.list(backupsDir))
        if (f.name.endsWith('.zip')) f,
    ]..sort((a, b) => b.name.compareTo(a.name));
    return list;
  }

  Future<void> _pruneBackups() async {
    final all = await backups();
    for (final old in all.skip(keepBackups)) {
      await files.delete('$backupsDir/${old.name}');
    }
  }

  /// Replaces this device's data with the backup [name].
  Future<int> restore(String name) async {
    final local = await _temp('restore.zip');
    await files.download('$backupsDir/$name', local.path);
    final contents = decodeBackup(await local.readAsBytes());
    await local.delete();
    final result = await replaceWithSnapshot(db, contents.snapshot);
    for (final MapEntry(key: file, value: bytes)
        in contents.attachments.entries) {
      await (await attachments.file(file)).writeAsBytes(bytes, flush: true);
    }
    return result.changed;
  }

  // Sync -------------------------------------------------------------------

  Future<SyncResult> syncNow() async {
    final own = 'device-$deviceId.json';
    var devices = 0;
    var changed = 0;

    // 1. Take in what the other devices have.
    for (final f in await files.list(syncDir)) {
      if (!f.name.startsWith('device-') ||
          !f.name.endsWith('.json') ||
          f.name == own) {
        continue;
      }
      final local = await _temp(f.name);
      await files.download('$syncDir/${f.name}', local.path);
      final snapshot =
          jsonDecode(await local.readAsString()) as Map<String, dynamic>;
      await local.delete();
      changed += (await mergeSnapshot(db, snapshot)).changed;
      devices++;
    }

    // 2. Exchange images: fetch missing ones, share new ones.
    final snapshot = await exportSnapshot(db, deviceId: deviceId, now: _now());
    final remote = {
      for (final f in await files.list('$syncDir/attachments')) f.name,
    };
    for (final name in snapshotAttachmentFiles(snapshot)) {
      final file = await attachments.file(name);
      final here = await file.exists();
      if (!here && remote.contains(name)) {
        await files.download('$syncDir/attachments/$name', file.path);
      } else if (here && !remote.contains(name)) {
        await files.upload(file.path, '$syncDir/attachments/$name');
      }
    }

    // 3. Publish this device's merged state.
    final out = await _temp(own);
    await out.writeAsString(jsonEncode(snapshot), flush: true);
    await files.upload(out.path, '$syncDir/$own');
    await out.delete();
    await prefs.setInt(lastSyncKey, _now().millisecondsSinceEpoch);
    return SyncResult(devices: devices, changed: changed);
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}${two(t.minute)}';
  }
}
