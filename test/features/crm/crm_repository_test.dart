import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/data/crm_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrmDatabase db;
  late CrmRepository repo;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 11, 12, 9);
    db = CrmDatabase(NativeDatabase.memory());
    repo = CrmRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<String> lead(String name, {String? statusId, String? source}) =>
      repo.createParty(
        PartiesCompanion.insert(
          kind: PartyKind.lead,
          name: name,
          statusId: Value(statusId),
          source: Value(source),
          dialCode: const Value('971'),
          mobile: const Value('501234567'),
        ),
      );

  test('a new database starts with Cold and Hot statuses', () async {
    final statuses = await repo.watchStatuses().first;
    expect(statuses.map((s) => s.name), ['Cold', 'Hot']);
  });

  test('statuses can be added, renamed and reordered', () async {
    final warm = await repo.addStatus(' Warm ', 0xFFFFA000);
    final [cold, hot, _] = await repo.watchStatuses().first;
    await repo.updateStatus(warm, name: 'Warm lead');
    await repo.reorderStatuses([cold.id, warm, hot.id]);

    expect((await repo.watchStatuses().first).map((s) => s.name), [
      'Cold',
      'Warm lead',
      'Hot',
    ]);
  });

  test('deleting a status moves its leads', () async {
    final [cold, hot] = await repo.watchStatuses().first;
    final id = await lead('Sara', statusId: hot.id);
    await repo.deleteStatus(hot.id, moveLeadsTo: cold.id);

    expect((await repo.watchStatuses().first).map((s) => s.name), ['Cold']);
    expect((await repo.watchParty(id).first)!.statusId, cold.id);
  });

  test('leads and clients are listed separately by name', () async {
    await lead('zara');
    await lead('Ahmed');
    await repo.createParty(
      PartiesCompanion.insert(kind: PartyKind.client, name: 'Bilal'),
    );

    expect((await repo.watchParties(PartyKind.lead).first).map((p) => p.name), [
      'Ahmed',
      'zara',
    ]);
    expect(
      (await repo.watchParties(PartyKind.client).first).map((p) => p.name),
      ['Bilal'],
    );
  });

  test('converting a lead keeps its details and stamps the time', () async {
    final id = await lead('Sara', source: 'Instagram');
    now = DateTime.utc(2026, 11, 13);
    await repo.convertToClient(id);

    final client = (await repo.watchParty(id).first)!;
    expect(client.kind, PartyKind.client);
    expect(client.source, 'Instagram');
    expect(client.mobile, '501234567');
    expect(client.convertedAt!.toUtc(), DateTime.utc(2026, 11, 13));
    expect(await repo.watchParties(PartyKind.lead).first, isEmpty);
  });

  test('a client has many deals, newest first', () async {
    final id = await repo.createParty(
      PartiesCompanion.insert(kind: PartyKind.client, name: 'Bilal'),
    );
    await repo.createDeal(
      DealsCompanion.insert(
        partyId: id,
        type: DealType.rented,
        item: 'Studio',
        date: DateTime(2025, 3, 1),
        location: const Value('JLT'),
      ),
    );
    await repo.createDeal(
      DealsCompanion.insert(
        partyId: id,
        type: DealType.bought,
        item: '2BR apartment',
        date: DateTime(2026, 6, 1),
        location: const Value('Dubai Marina'),
      ),
    );

    final deals = await repo.watchDeals(id).first;
    expect(deals.map((d) => (d.type, d.item, d.location)), [
      (DealType.bought, '2BR apartment', 'Dubai Marina'),
      (DealType.rented, 'Studio', 'JLT'),
    ]);
  });

  test('deletes are soft and take the deals along', () async {
    final id = await repo.createParty(
      PartiesCompanion.insert(kind: PartyKind.client, name: 'Bilal'),
    );
    await repo.createDeal(
      DealsCompanion.insert(
        partyId: id,
        type: DealType.bought,
        item: 'Villa',
        date: DateTime(2026),
      ),
    );
    await repo.deleteParty(id);

    expect(await repo.watchParty(id).first, isNull);
    expect(await repo.watchDeals(id).first, isEmpty);
    // Still stored, marked deleted, so the deletion can sync.
    final rows = await db.select(db.parties).get();
    expect(rows.single.deletedAt!.toUtc(), now);
  });

  test('sources used so far are suggested once each', () async {
    await lead('A', source: 'Instagram');
    await lead('B', source: 'Referral');
    await lead('C', source: 'Instagram');
    expect(await repo.watchSources().first, ['Instagram', 'Referral']);
  });
}
