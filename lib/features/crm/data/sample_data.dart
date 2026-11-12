import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_repository.dart';
import 'crm_database.dart';
import 'crm_repository.dart';

/// Realistic demo leads, clients, purchases and activities for trying the
/// app. Everything added is remembered so [removeSampleData] can take it
/// out again without touching the user's own records.
class SampleData {
  SampleData(this._db, this._prefs, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CrmDatabase _db;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static const _key = 'sample_data_ids';

  bool get isLoaded => _prefs.getString(_key) != null;

  /// Adds the sample set; returns (leads, clients, activities) counts.
  Future<(int, int, int)> add({int seed = 7}) async {
    final rnd = Random(seed);
    final now = _now();
    final crm = CrmRepository(_db, clock: _now);
    final ids = <String, List<String>>{
      'parties': [],
      'activities': [],
      'statuses': [],
    };

    // Statuses: reuse the user's, add two pipeline stages if missing.
    final statuses = await crm.watchStatuses().first;
    String statusId(String name, int color) {
      final found = statuses.where(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
      );
      return found.isEmpty ? '' : found.first.id;
    }

    var warm = statusId('Warm', 0);
    if (warm.isEmpty) {
      warm = await crm.addStatus('Warm', 0xFFFFA000);
      ids['statuses']!.add(warm);
    }
    var viewing = statusId('Viewing', 0);
    if (viewing.isEmpty) {
      viewing = await crm.addStatus('Viewing', 0xFF8E5CF7);
      ids['statuses']!.add(viewing);
    }
    final all = await crm.watchStatuses().first;
    final cold = statusId('Cold', 0).ifEmpty(all.first.id);
    final hot = statusId('Hot', 0).ifEmpty(all.last.id);
    final leadStatuses = [cold, cold, cold, warm, warm, hot, hot, viewing];

    final usedNumbers = <String>{};
    T pick<T>(List<T> list) => list[rnd.nextInt(list.length)];
    DateTime daysAgo(int min, int max) => now.subtract(
      Duration(days: min + rnd.nextInt(max - min + 1), hours: rnd.nextInt(10)),
    );

    Future<String> person(PartyKind kind, int i) async {
      final p = pick(_people);
      final first = pick(p.first);
      final last = pick(p.last);
      // Most people here use a UAE number; some keep their home number.
      final local = rnd.nextDouble() < 0.7;
      final plan = local ? _phones['AE']! : (_phones[p.iso] ?? _phones['AE']!);
      final (dial, national) = _number(rnd, plan, usedNumbers);
      final residence = local
          ? 'AE'
          : pick(['AE', 'AE', 'AE', p.iso, 'SA', 'QA', 'GB']);
      final source = pick(_sources);
      final created = kind == PartyKind.lead
          ? daysAgo(0, 120)
          : daysAgo(120, 900);
      final id = await _db
          .into(_db.parties)
          .insertReturning(
            PartiesCompanion.insert(
              kind: kind,
              name: '$first $last',
              dialCode: Value(dial),
              mobile: Value(national),
              nationality: Value(p.iso),
              country: Value(residence),
              source: Value(source.$1),
              subSource: Value(source.$2.isEmpty ? null : pick(source.$2)),
              statusId: Value(
                kind == PartyKind.lead ? pick(leadStatuses) : null,
              ),
              convertedAt: Value(
                kind == PartyKind.client && rnd.nextBool()
                    ? created.add(Duration(days: 20 + rnd.nextInt(60)))
                    : null,
              ),
              createdAt: Value(created),
              updatedAt: Value(created),
            ),
          )
          .then((r) => r.id);
      ids['parties']!.add(id);
      return id;
    }

    final leads = [
      for (var i = 0; i < 40; i++) await person(PartyKind.lead, i),
    ];
    final clients = [
      for (var i = 0; i < 18; i++) await person(PartyKind.client, i),
    ];

    // Purchases and rentals: one to three per client.
    for (final client in clients) {
      for (var d = 0, n = 1 + rnd.nextInt(3); d < n; d++) {
        final bought = rnd.nextDouble() < 0.55;
        final date = daysAgo(10, 1000);
        await _db
            .into(_db.deals)
            .insert(
              DealsCompanion.insert(
                partyId: client,
                type: bought ? DealType.bought : DealType.rented,
                item: pick(bought ? _bought : _rented),
                date: DateTime(date.year, date.month, date.day),
                location: Value(pick(_locations)),
                notes: Value(rnd.nextDouble() < 0.4 ? pick(_dealNotes) : null),
                createdAt: Value(date),
                updatedAt: Value(date),
              ),
            );
      }
    }

    // Activities around today: overdue, today, upcoming and done.
    final activities = ActivityRepository(_db, clock: _now);
    final names = {
      for (final p in await _db.select(_db.parties).get()) p.id: p.name,
    };
    final people = [...leads, ...leads, ...clients];
    for (var i = 0; i < 30; i++) {
      final type = pick(_activityTypes);
      final partyId = rnd.nextDouble() < 0.85 ? pick(people) : null;
      final who = partyId == null ? null : names[partyId]!.split(' ').first;
      // Always show every group: a few overdue, a few today, then a spread
      // from a week back (mostly done) to about twelve days ahead.
      final dayOffset = i < 3
          ? -1 - i
          : i < 7
          ? 0
          : -6 + rnd.nextInt(18);
      final due = DateTime(now.year, now.month, now.day + dayOffset).add(
        Duration(hours: 9 + rnd.nextInt(9), minutes: pick([0, 15, 30, 45])),
      );
      final done = i >= 7 && dayOffset < 0 && rnd.nextDouble() < 0.6;
      final note = pick(_notes);
      final id = await activities.createActivity(
        ActivitiesCompanion.insert(
          type: type,
          priority: pick(ActivityPriority.values),
          title: _title(type, who, rnd),
          dueAt: Value(rnd.nextDouble() < 0.9 ? due : null),
          completedAt: Value(done ? due.add(const Duration(hours: 1)) : null),
          partyId: Value(partyId),
          noteJson: Value(jsonEncode(note.$1)),
          notePlain: Value(note.$2),
        ),
      );
      ids['activities']!.add(id);
    }

    await _prefs.setString(_key, jsonEncode(ids));
    return (leads.length, clients.length, ids['activities']!.length);
  }

  /// Soft-deletes everything [add] created; the user's own records stay.
  Future<void> remove() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final ids = (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).cast<String>()),
    );
    final crm = CrmRepository(_db, clock: _now);
    final activities = ActivityRepository(_db, clock: _now);
    for (final id in ids['activities'] ?? const <String>[]) {
      await activities.deleteActivity(id);
    }
    for (final id in ids['parties'] ?? const <String>[]) {
      await crm.deleteParty(id);
    }
    // Drop the sample statuses unless the user's own leads now use them.
    final statuses = await crm.watchStatuses().first;
    final leads = await crm.watchParties(PartyKind.lead).first;
    for (final id in ids['statuses'] ?? const <String>[]) {
      final keep = statuses.where((s) => s.id != id).firstOrNull;
      if (keep == null || leads.any((l) => l.statusId == id)) continue;
      await crm.deleteStatus(id, moveLeadsTo: keep.id);
    }
    await _prefs.remove(_key);
  }

  /// Person-specific titles when there is someone, general ones otherwise.
  static String _title(ActivityType type, String? who, Random rnd) {
    final options = who != null
        ? switch (type) {
            ActivityType.call => ['Call $who back', 'Follow-up call with $who'],
            ActivityType.meeting => [
              'Viewing with $who',
              'Meeting with $who at the office',
            ],
            ActivityType.task => [
              'Prepare offer for $who',
              'Send contract draft to $who',
            ],
            ActivityType.email => [
              'Email brochure to $who',
              'Send payment plan to $who',
            ],
            ActivityType.lunch => ['Lunch with $who'],
          }
        : switch (type) {
            ActivityType.call => ['Call about the Marina listing'],
            ActivityType.meeting => ['Team pipeline review'],
            ActivityType.task => ['Update Property Finder listings'],
            ActivityType.email => ['Newsletter to past clients'],
            ActivityType.lunch => ['Lunch with developer sales team'],
          };
    return options[rnd.nextInt(options.length)];
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// (calling code, national prefixes, national length).
typedef _PhonePlan = (String, List<String>, int);

const _phones = <String, _PhonePlan>{
  'AE': ('971', ['50', '52', '54', '55', '56', '58'], 9),
  'IN': ('91', ['98', '99', '97', '81', '70'], 10),
  'GB': ('44', ['7400', '7700', '7911'], 10),
  'EG': ('20', ['10', '11', '12'], 10),
  'PK': ('92', ['300', '321', '333'], 10),
  'SA': ('966', ['50', '55', '56'], 9),
  'JO': ('962', ['77', '78', '79'], 9),
  'LB': ('961', ['70', '71'], 8),
  'PH': ('63', ['917', '905', '927'], 10),
  'RU': ('7', ['916', '903', '926'], 10),
  'US': ('1', ['41555501', '20255501'], 10),
  'FR': ('33', ['6'], 9),
  'DE': ('49', ['151', '160', '170'], 11),
  'LK': ('94', ['77', '71'], 9),
  'BD': ('880', ['17', '18', '19'], 10),
  'NP': ('977', ['98'], 10),
};

(String, String) _number(Random rnd, _PhonePlan plan, Set<String> used) {
  final (dial, prefixes, length) = plan;
  while (true) {
    final prefix = prefixes[rnd.nextInt(prefixes.length)];
    final rest = List.generate(
      length - prefix.length,
      (_) => rnd.nextInt(10),
    ).join();
    final national = '$prefix$rest';
    final e164 = '+$dial$national';
    if (used.contains(e164)) continue;
    try {
      if (!PhoneNumber.parse(e164).isValid(type: PhoneNumberType.mobile)) {
        continue;
      }
    } on PhoneNumberException {
      continue;
    }
    used.add(e164);
    return (dial, national);
  }
}

typedef _People = ({String iso, List<String> first, List<String> last});

const List<_People> _people = [
  (
    iso: 'AE',
    first: [
      'Ahmed',
      'Mohammed',
      'Khalid',
      'Fatima',
      'Mariam',
      'Hamdan',
      'Noura',
    ],
    last: ['Al Mansoori', 'Al Shamsi', 'Al Nuaimi', 'Al Ketbi', 'Al Falasi'],
  ),
  (
    iso: 'IN',
    first: ['Priya', 'Arjun', 'Rahul', 'Ananya', 'Vikram', 'Sneha', 'Rohan'],
    last: ['Sharma', 'Nair', 'Patel', 'Menon', 'Iyer', 'Kapoor', 'Reddy'],
  ),
  (
    iso: 'IN',
    first: ['Aisha', 'Faisal', 'Imran', 'Zara', 'Sameer'],
    last: ['Khan', 'Shaikh', 'Qureshi', 'Siddiqui'],
  ),
  (
    iso: 'PK',
    first: ['Ali', 'Hassan', 'Ayesha', 'Bilal', 'Sana', 'Usman'],
    last: ['Raza', 'Malik', 'Chaudhry', 'Butt', 'Hussain'],
  ),
  (
    iso: 'EG',
    first: ['Omar', 'Mona', 'Karim', 'Yasmin', 'Tarek', 'Nour'],
    last: ['Saleh', 'Mostafa', 'Fahmy', 'Hassan', 'El Sayed'],
  ),
  (
    iso: 'JO',
    first: ['Rami', 'Lina', 'Zaid', 'Dana', 'Hamza'],
    last: ['Odeh', 'Haddad', 'Khoury', 'Nasser'],
  ),
  (
    iso: 'LB',
    first: ['Georges', 'Rita', 'Karim', 'Maya', 'Elie'],
    last: ['Khoury', 'Haddad', 'Saab', 'Aoun', 'Rizk'],
  ),
  (
    iso: 'SA',
    first: ['Abdullah', 'Faisal', 'Reem', 'Turki', 'Lama'],
    last: ['Al Qahtani', 'Al Harbi', 'Al Otaibi', 'Al Ghamdi'],
  ),
  (
    iso: 'GB',
    first: ['James', 'Emily', 'Oliver', 'Charlotte', 'Harry', 'Sophie'],
    last: ['Smith', 'Taylor', 'Brown', 'Wilson', 'Clarke', 'Bennett'],
  ),
  (
    iso: 'PH',
    first: ['Maria', 'Jose', 'Angelica', 'Mark', 'Kristine'],
    last: ['Santos', 'Reyes', 'Cruz', 'Bautista', 'Garcia'],
  ),
  (
    iso: 'RU',
    first: ['Anastasia', 'Dmitry', 'Elena', 'Sergey', 'Olga'],
    last: ['Ivanova', 'Petrov', 'Smirnova', 'Volkov', 'Kuznetsov'],
  ),
  (
    iso: 'US',
    first: ['Michael', 'Jessica', 'David', 'Ashley', 'Chris'],
    last: ['Johnson', 'Miller', 'Davis', 'Anderson', 'Thomas'],
  ),
  (
    iso: 'FR',
    first: ['Camille', 'Louis', 'Chloé', 'Antoine'],
    last: ['Dubois', 'Martin', 'Bernard', 'Laurent'],
  ),
  (
    iso: 'DE',
    first: ['Lukas', 'Anna', 'Felix', 'Laura'],
    last: ['Müller', 'Schmidt', 'Fischer', 'Weber'],
  ),
  (
    iso: 'LK',
    first: ['Nuwan', 'Dilani', 'Kasun', 'Ishara'],
    last: ['Perera', 'Fernando', 'Silva', 'Jayasuriya'],
  ),
  (
    iso: 'BD',
    first: ['Tanvir', 'Nusrat', 'Rafiq', 'Sadia'],
    last: ['Rahman', 'Hossain', 'Islam', 'Ahmed'],
  ),
  (
    iso: 'NP',
    first: ['Sita', 'Bikash', 'Anil', 'Pooja'],
    last: ['Shrestha', 'Gurung', 'Thapa', 'Rai'],
  ),
];

/// (source, sub sources).
const _sources = <(String, List<String>)>[
  ('Instagram', ['Ramadan campaign', 'Story ad', 'DM']),
  ('Instagram', ['Reel', 'Ramadan campaign']),
  ('Facebook Ads', ['Lead form', 'Retargeting']),
  (
    'Property Finder',
    ['Listing PF-2041', 'Listing PF-3317', 'Listing PF-1189'],
  ),
  ('Bayut', ['Marina 2BR listing', 'JVC studio listing']),
  ('Referral', ['Past client', 'Friend', 'Colleague']),
  ('Website', ['Contact form', 'WhatsApp chat']),
  ('Walk-in', ['Marina office']),
  ('Cityscape 2026', []),
  ('Google Ads', ['Off-plan search']),
];

const _bought = [
  '2BR apartment',
  '1BR apartment',
  '3BR villa',
  'Townhouse',
  'Studio (off-plan)',
  'Penthouse',
  'Office unit',
];

const _rented = [
  'Studio',
  '1BR apartment',
  '2BR apartment',
  'Villa',
  'Retail shop',
];

const _locations = [
  'Dubai Marina',
  'JLT',
  'Downtown Dubai',
  'Business Bay',
  'Palm Jumeirah',
  'Arabian Ranches',
  'JVC',
  'Dubai Hills',
  'Al Reem Island',
  'Saadiyat Island',
];

const _dealNotes = [
  'Paid in 4 cheques',
  'Cash buyer, transfer done at DLD',
  'Mortgage with ENBD, 25 years',
  'Renewal due next year',
  'Referred two friends afterwards',
];

const _activityTypes = [
  ActivityType.call,
  ActivityType.call,
  ActivityType.call,
  ActivityType.meeting,
  ActivityType.meeting,
  ActivityType.task,
  ActivityType.task,
  ActivityType.email,
  ActivityType.lunch,
];

/// (Quill Delta, plain text).
final List<(List<Map<String, Object>>, String)> _notes = [
  (
    [
      {'insert': 'Budget around '},
      {
        'insert': 'AED 1.8M',
        'attributes': {'bold': true},
      },
      {'insert': ', prefers sea view.\n'},
    ],
    'Budget around AED 1.8M, prefers sea view.',
  ),
  (
    [
      {'insert': 'Bring floor plans and payment plan\n'},
      {
        'insert': 'Check parking availability\n',
        'attributes': {'list': 'unchecked'},
      },
    ],
    'Bring floor plans and payment plan\nCheck parking availability',
  ),
  (
    [
      {
        'insert': 'Hot lead',
        'attributes': {'bold': true, 'color': '#FFE5484D'},
      },
      {'insert': ' – wants to move before school starts.\n'},
    ],
    'Hot lead – wants to move before school starts.',
  ),
  (
    [
      {'insert': 'Asked for 3 options in '},
      {
        'insert': 'JVC',
        'attributes': {'italic': true},
      },
      {'insert': ' under AED 90k/year.\n'},
    ],
    'Asked for 3 options in JVC under AED 90k/year.',
  ),
  (
    [
      {'insert': 'Follow up after Eid. Interested in off-plan.\n'},
    ],
    'Follow up after Eid. Interested in off-plan.',
  ),
];
