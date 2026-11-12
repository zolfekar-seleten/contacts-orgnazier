import 'package:country_contacts/features/crm/data/activity_repository.dart';
import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/crm/data/crm_repository.dart';
import 'package:country_contacts/features/crm/data/sample_data.dart';
import 'package:country_contacts/features/crm/domain/party_phone.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CrmDatabase db;
  late CrmRepository crm;
  late ActivityRepository activities;
  late SampleData sample;
  final now = DateTime(2026, 11, 12, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = CrmDatabase(NativeDatabase.memory());
    crm = CrmRepository(db, clock: () => now);
    activities = ActivityRepository(db, clock: () => now);
    sample = SampleData(
      db,
      await SharedPreferences.getInstance(),
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  test('adds leads, clients with purchases, and activities', () async {
    expect(await sample.add(), (40, 18, 30));
    expect(sample.isLoaded, isTrue);

    final leads = await crm.watchParties(PartyKind.lead).first;
    final clients = await crm.watchParties(PartyKind.client).first;
    expect(leads, hasLength(40));
    expect(clients, hasLength(18));
    expect(
      (await crm.watchStatuses().first).map((s) => s.name),
      containsAll(['Cold', 'Hot', 'Warm', 'Viewing']),
    );
    for (final c in clients) {
      expect((await crm.watchDeals(c.id).first).length, inInclusiveRange(1, 3));
    }
    final acts = await activities.watchActivities().first;
    expect(acts, hasLength(30));
    final today = DateTime(now.year, now.month, now.day);
    bool open(a) => a.completedAt == null;
    expect(acts.any((a) => a.completedAt != null), isTrue, reason: 'done');
    expect(
      acts.any((a) => open(a) && a.dueAt != null && a.dueAt!.isBefore(today)),
      isTrue,
      reason: 'overdue',
    );
    expect(
      acts.any(
        (a) =>
            open(a) &&
            a.dueAt != null &&
            !a.dueAt!.isBefore(today) &&
            a.dueAt!.isBefore(today.add(const Duration(days: 1))),
      ),
      isTrue,
      reason: 'today',
    );
    expect(acts.any((a) => a.dueAt?.isAfter(now) ?? false), isTrue);
    // General titles only on activities without a person.
    for (final a in acts.where((a) => a.partyId != null)) {
      expect(
        a.title,
        isNot(
          anyOf(
            'Team pipeline review',
            'Lunch with developer sales team',
            'Newsletter to past clients',
            'Update Property Finder listings',
            'Call about the Marina listing',
          ),
        ),
      );
    }
  });

  test('every number is a valid, unique mobile with full details', () async {
    await sample.add();
    final people = [
      ...await crm.watchParties(PartyKind.lead).first,
      ...await crm.watchParties(PartyKind.client).first,
    ];
    final numbers = <String>{};
    for (final p in people) {
      expect(
        PhoneNumber.parse(p.e164!).isValid(type: PhoneNumberType.mobile),
        isTrue,
        reason: '${p.name} ${p.e164}',
      );
      expect(numbers.add(p.e164!), isTrue, reason: 'duplicate ${p.e164}');
      expect(p.nationality, isNotNull);
      expect(p.country, isNotNull);
      expect(p.source, isNotNull);
    }
  });

  test('removing takes out only the sample records', () async {
    final mine = await crm.createParty(
      PartiesCompanion.insert(kind: PartyKind.lead, name: 'My own lead'),
    );
    await sample.add();
    await sample.remove();

    expect(sample.isLoaded, isFalse);
    expect((await crm.watchParties(PartyKind.lead).first).map((p) => p.id), [
      mine,
    ]);
    expect(await crm.watchParties(PartyKind.client).first, isEmpty);
    expect(await activities.watchActivities().first, isEmpty);
    expect((await crm.watchStatuses().first).map((s) => s.name), [
      'Cold',
      'Hot',
    ]);
  });

  test('statuses the user already has are reused', () async {
    await crm.addStatus('warm', 0xFF000000);
    await sample.add();
    final names = (await crm.watchStatuses().first).map((s) => s.name);
    expect(names.where((n) => n.toLowerCase() == 'warm'), hasLength(1));
    await sample.remove();
    expect(
      (await crm.watchStatuses().first).map((s) => s.name),
      contains('warm'),
    );
  });
}
