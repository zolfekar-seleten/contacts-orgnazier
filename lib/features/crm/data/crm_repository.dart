import 'package:drift/drift.dart';

import 'crm_database.dart';

/// Reads and writes leads, clients, statuses and deals. Deletes are soft
/// (they set `deletedAt`) and every write stamps `updatedAt`, so a later
/// sync can merge changes from several devices.
class CrmRepository {
  CrmRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CrmDatabase _db;
  final DateTime Function() _now;

  // Statuses ---------------------------------------------------------------

  Stream<List<LeadStatus>> watchStatuses() =>
      (_db.select(_db.leadStatuses)
            ..where((s) => s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm(expression: s.position)]))
          .watch();

  Future<String> addStatus(String name, int color) async {
    final last =
        await (_db.selectOnly(_db.leadStatuses)
              ..addColumns([_db.leadStatuses.position.max()]))
            .map((r) => r.read(_db.leadStatuses.position.max()))
            .getSingle();
    final row = await _db
        .into(_db.leadStatuses)
        .insertReturning(
          LeadStatusesCompanion.insert(
            name: name.trim(),
            color: color,
            position: (last ?? -1) + 1,
            createdAt: Value(_now()),
            updatedAt: Value(_now()),
          ),
        );
    return row.id;
  }

  Future<void> updateStatus(String id, {String? name, int? color}) =>
      (_db.update(_db.leadStatuses)..where((s) => s.id.equals(id))).write(
        LeadStatusesCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          color: Value.absentIfNull(color),
          updatedAt: Value(_now()),
        ),
      );

  /// Saves the order shown in the status list.
  Future<void> reorderStatuses(List<String> ids) => _db.transaction(() async {
    for (final (i, id) in ids.indexed) {
      await (_db.update(_db.leadStatuses)..where((s) => s.id.equals(id))).write(
        LeadStatusesCompanion(position: Value(i), updatedAt: Value(_now())),
      );
    }
  });

  /// Deletes a status, moving its leads to [moveLeadsTo].
  Future<void> deleteStatus(
    String id, {
    required String moveLeadsTo,
  }) => _db.transaction(() async {
    await (_db.update(_db.parties)..where((p) => p.statusId.equals(id))).write(
      PartiesCompanion(statusId: Value(moveLeadsTo), updatedAt: Value(_now())),
    );
    await (_db.update(_db.leadStatuses)..where((s) => s.id.equals(id))).write(
      LeadStatusesCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
    );
  });

  // Leads and clients ------------------------------------------------------

  Stream<List<Party>> watchParties(PartyKind kind) =>
      (_db.select(_db.parties)
            ..where((p) => p.kind.equalsValue(kind) & p.deletedAt.isNull())
            ..orderBy([
              (p) => OrderingTerm(expression: p.name.collate(Collate.noCase)),
            ]))
          .watch();

  Stream<Party?> watchParty(String id) => (_db.select(
    _db.parties,
  )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).watchSingleOrNull();

  /// Sources used so far, for suggestions while typing.
  Stream<List<String>> watchSources() => _distinct(_db.parties.source);

  Stream<List<String>> watchSubSources() => _distinct(_db.parties.subSource);

  Stream<List<String>> _distinct(GeneratedColumn<String> column) {
    final query = _db.selectOnly(_db.parties, distinct: true)
      ..addColumns([column])
      ..where(column.isNotNull() & _db.parties.deletedAt.isNull())
      ..orderBy([OrderingTerm(expression: column.collate(Collate.noCase))]);
    return query.map((r) => r.read(column)!).watch();
  }

  /// Inserts a new lead or client and returns its id.
  Future<String> createParty(PartiesCompanion data) async {
    final row = await _db
        .into(_db.parties)
        .insertReturning(
          data.copyWith(createdAt: Value(_now()), updatedAt: Value(_now())),
        );
    return row.id;
  }

  /// Inserts many leads or clients in one transaction (spreadsheet import).
  Future<void> insertParties(List<PartiesCompanion> rows) => _db.batch((b) {
    b.insertAll(_db.parties, [
      for (final r in rows)
        r.copyWith(createdAt: Value(_now()), updatedAt: Value(_now())),
    ]);
  });

  /// Mobile numbers already saved, as E.164, for skipping duplicates.
  Future<Set<String>> savedNumbers() async {
    final rows = await (_db.select(
      _db.parties,
    )..where((p) => p.deletedAt.isNull() & p.mobile.isNotNull())).get();
    return {
      for (final p in rows)
        if (p.dialCode != null) '+${p.dialCode}${p.mobile}',
    };
  }

  Future<void> updateParty(String id, PartiesCompanion data) =>
      (_db.update(_db.parties)..where((p) => p.id.equals(id))).write(
        data.copyWith(updatedAt: Value(_now())),
      );

  /// Turns a lead into a client, keeping all its details.
  Future<void> convertToClient(String id) => updateParty(
    id,
    PartiesCompanion(
      kind: const Value(PartyKind.client),
      convertedAt: Value(_now()),
    ),
  );

  /// Soft-deletes a lead or client together with its deals.
  Future<void> deleteParty(String id) => _db.transaction(() async {
    final stamp = PartiesCompanion(
      deletedAt: Value(_now()),
      updatedAt: Value(_now()),
    );
    await (_db.update(_db.parties)..where((p) => p.id.equals(id))).write(stamp);
    await (_db.update(_db.deals)..where((d) => d.partyId.equals(id))).write(
      DealsCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
    );
  });

  // Deals ------------------------------------------------------------------

  Stream<List<Deal>> watchDeals(String partyId) =>
      (_db.select(_db.deals)
            ..where((d) => d.partyId.equals(partyId) & d.deletedAt.isNull())
            ..orderBy([
              (d) => OrderingTerm(expression: d.date, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<String> createDeal(DealsCompanion data) async {
    final row = await _db
        .into(_db.deals)
        .insertReturning(
          data.copyWith(createdAt: Value(_now()), updatedAt: Value(_now())),
        );
    return row.id;
  }

  Future<void> updateDeal(String id, DealsCompanion data) =>
      (_db.update(_db.deals)..where((d) => d.id.equals(id))).write(
        data.copyWith(updatedAt: Value(_now())),
      );

  Future<void> deleteDeal(String id) =>
      (_db.update(_db.deals)..where((d) => d.id.equals(id))).write(
        DealsCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
      );
}
