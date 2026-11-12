import 'package:drift/drift.dart';

import 'crm_database.dart';

/// Reads and writes activities and their image attachments. Like
/// [CrmRepository], deletes are soft and writes stamp `updatedAt`.
class ActivityRepository {
  ActivityRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CrmDatabase _db;
  final DateTime Function() _now;

  /// Open activities by due date (undated last), then done ones, newest
  /// first. Limited to one lead or client when [partyId] is given.
  Stream<List<Activity>> watchActivities({String? partyId}) {
    final a = _db.activities;
    final query = _db.select(a)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            (partyId == null
                ? const Constant(true)
                : t.partyId.equals(partyId)),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.completedAt.isNotNull()),
        (t) => OrderingTerm(expression: t.dueAt.isNull()),
        (t) => OrderingTerm(expression: t.dueAt),
        (t) => OrderingTerm(expression: t.completedAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<Activity?> watchActivity(String id) => (_db.select(
    _db.activities,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  /// How many images each activity has.
  Stream<Map<String, int>> watchAttachmentCounts() {
    final t = _db.activityAttachments;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([t.activityId, count])
      ..where(t.deletedAt.isNull())
      ..groupBy([t.activityId]);
    return query.watch().map(
      (rows) => {for (final r in rows) r.read(t.activityId)!: r.read(count)!},
    );
  }

  Stream<List<ActivityAttachment>> watchAttachments(String activityId) =>
      (_db.select(_db.activityAttachments)
            ..where(
              (t) => t.activityId.equals(activityId) & t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  Future<String> createActivity(
    ActivitiesCompanion data, {
    List<String> attachments = const [],
  }) => _db.transaction(() async {
    final row = await _db
        .into(_db.activities)
        .insertReturning(
          data.copyWith(createdAt: Value(_now()), updatedAt: Value(_now())),
        );
    for (final file in attachments) {
      await addAttachment(row.id, file);
    }
    return row.id;
  });

  Future<void> updateActivity(String id, ActivitiesCompanion data) =>
      (_db.update(_db.activities)..where((t) => t.id.equals(id))).write(
        data.copyWith(updatedAt: Value(_now())),
      );

  Future<void> setDone(String id, {required bool done}) => updateActivity(
    id,
    ActivitiesCompanion(completedAt: Value(done ? _now() : null)),
  );

  /// Soft-deletes an activity and its attachments; returns the attachment
  /// file names so the caller can remove the files.
  Future<List<String>> deleteActivity(String id) => _db.transaction(() async {
    final files =
        await (_db.select(_db.activityAttachments)
              ..where((t) => t.activityId.equals(id) & t.deletedAt.isNull()))
            .map((r) => r.fileName)
            .get();
    await (_db.update(_db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
    );
    await (_db.update(
      _db.activityAttachments,
    )..where((t) => t.activityId.equals(id))).write(
      ActivityAttachmentsCompanion(
        deletedAt: Value(_now()),
        updatedAt: Value(_now()),
      ),
    );
    return files;
  });

  Future<String> addAttachment(String activityId, String fileName) async {
    final row = await _db
        .into(_db.activityAttachments)
        .insertReturning(
          ActivityAttachmentsCompanion.insert(
            activityId: activityId,
            fileName: fileName,
            createdAt: Value(_now()),
            updatedAt: Value(_now()),
          ),
        );
    return row.id;
  }

  Future<void> deleteAttachment(String id) =>
      (_db.update(
        _db.activityAttachments,
      )..where((t) => t.id.equals(id))).write(
        ActivityAttachmentsCompanion(
          deletedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
}
