import 'package:drift/drift.dart';

import '../../crm/data/crm_database.dart';

/// Format version of exported snapshots (not the database schema).
const snapshotFormat = 1;

class SnapshotTooNewException implements Exception {
  const SnapshotTooNewException();

  @override
  String toString() =>
      'This backup was made by a newer version of Contacts Organizer. '
      'Update the app, then try again.';
}

/// Every row of every table, deleted ones included, as JSON. Used for
/// backups and for syncing devices through iCloud.
Future<Map<String, dynamic>> exportSnapshot(
  CrmDatabase db, {
  required String deviceId,
  required DateTime now,
}) async {
  List<Map<String, dynamic>> rows(List<DataClass> list) => [
    for (final r in list) r.toJson(),
  ];
  return {
    'format': snapshotFormat,
    'schema': db.schemaVersion,
    'deviceId': deviceId,
    'exportedAt': now.toUtc().toIso8601String(),
    'tables': {
      'lead_statuses': rows(await db.select(db.leadStatuses).get()),
      'parties': rows(await db.select(db.parties).get()),
      'deals': rows(await db.select(db.deals).get()),
      'activities': rows(await db.select(db.activities).get()),
      'activity_attachments': rows(
        await db.select(db.activityAttachments).get(),
      ),
    },
  };
}

/// Counts of rows a merge or restore changed.
class MergeResult {
  const MergeResult(this.changed);

  final int changed;
}

typedef _TableSpec = (
  String key,
  TableInfo<Table, DataClass> table,
  Insertable<DataClass> Function(Map<String, dynamic>) parse,
  DateTime Function(DataClass) updatedAt,
);

/// Parents before children, so foreign keys always resolve.
List<_TableSpec> _tables(CrmDatabase db) => [
  (
    'lead_statuses',
    db.leadStatuses,
    LeadStatus.fromJson,
    (r) => (r as LeadStatus).updatedAt,
  ),
  ('parties', db.parties, Party.fromJson, (r) => (r as Party).updatedAt),
  ('deals', db.deals, Deal.fromJson, (r) => (r as Deal).updatedAt),
  (
    'activities',
    db.activities,
    Activity.fromJson,
    (r) => (r as Activity).updatedAt,
  ),
  (
    'activity_attachments',
    db.activityAttachments,
    ActivityAttachment.fromJson,
    (r) => (r as ActivityAttachment).updatedAt,
  ),
];

String _id(Map<String, dynamic> json) => json['id'] as String;

DateTime _updated(Map<String, dynamic> json) =>
    const ValueSerializer.defaults().fromJson<DateTime>(json['updatedAt']);

void _checkVersion(CrmDatabase db, Map<String, dynamic> snapshot) {
  final format = snapshot['format'] as int? ?? 0;
  final schema = snapshot['schema'] as int? ?? 0;
  if (format > snapshotFormat || schema > db.schemaVersion) {
    throw const SnapshotTooNewException();
  }
}

/// Merges another device's [snapshot] into [db]: a row is taken when it is
/// new here or was edited more recently there (deletions are edits too).
Future<MergeResult> mergeSnapshot(
  CrmDatabase db,
  Map<String, dynamic> snapshot,
) async {
  _checkVersion(db, snapshot);
  final tables = (snapshot['tables'] as Map).cast<String, dynamic>();
  var changed = 0;
  await db.transaction(() async {
    for (final (key, table, parse, updatedAt) in _tables(db)) {
      final incoming = (tables[key] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (incoming.isEmpty) continue;
      final local = {
        for (final r in await db.select(table).get())
          (r.toJson()['id'] as String): updatedAt(r),
      };
      for (final json in incoming) {
        final mine = local[_id(json)];
        if (mine != null && !_updated(json).isAfter(mine)) continue;
        await db.into(table).insertOnConflictUpdate(parse(json));
        changed++;
      }
    }
  });
  return MergeResult(changed);
}

/// Replaces everything in [db] with [snapshot] (restoring a backup).
Future<MergeResult> replaceWithSnapshot(
  CrmDatabase db,
  Map<String, dynamic> snapshot,
) async {
  _checkVersion(db, snapshot);
  final tables = (snapshot['tables'] as Map).cast<String, dynamic>();
  var count = 0;
  await db.transaction(() async {
    for (final (_, table, _, _) in _tables(db).reversed) {
      await db.delete(table).go();
    }
    for (final (key, table, parse, _) in _tables(db)) {
      final rows = (tables[key] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      await db.batch(
        (b) => b.insertAll(table, [for (final json in rows) parse(json)]),
      );
      count += rows.length;
    }
  });
  return MergeResult(count);
}

/// Attachment file names a snapshot refers to (not deleted).
Set<String> snapshotAttachmentFiles(Map<String, dynamic> snapshot) => {
  for (final json
      in ((snapshot['tables'] as Map)['activity_attachments'] as List? ??
              const [])
          .cast<Map<String, dynamic>>())
    if (json['deletedAt'] == null) json['fileName'] as String,
};
