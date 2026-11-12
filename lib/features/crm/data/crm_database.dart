import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'crm_database.g.dart';

const _uuid = Uuid();

/// A person the user is working with: a lead until converted to a client.
enum PartyKind { lead, client }

/// What a client did with a property or product.
enum DealType {
  bought('Bought'),
  rented('Rented');

  const DealType(this.label);
  final String label;
}

enum ActivityType {
  call('Call'),
  meeting('Meeting'),
  task('Task'),
  email('Email'),
  lunch('Lunch');

  const ActivityType(this.label);
  final String label;
}

enum ActivityPriority {
  high('High'),
  medium('Medium'),
  low('Low');

  const ActivityPriority(this.label);
  final String label;
}

/// Columns every synced table shares. UUID keys, edit times and soft
/// deletes let records from several devices be merged later (iCloud sync).
mixin SyncedTable on Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  /// Set instead of deleting the row, so the deletion can sync too.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lead statuses the user can add to, rename, recolour and reorder.
@DataClassName('LeadStatus')
class LeadStatuses extends Table with SyncedTable {
  TextColumn get name => text()();

  /// ARGB colour value.
  IntColumn get color => integer()();
  IntColumn get position => integer()();
}

/// Leads and clients in one table: converting a lead keeps its history.
@DataClassName('Party')
class Parties extends Table with SyncedTable {
  IntColumn get kind => intEnum<PartyKind>()();
  TextColumn get name => text()();

  /// Country calling code without `+`, e.g. `971`.
  TextColumn get dialCode => text().nullable()();

  /// National number digits, without the calling code.
  TextColumn get mobile => text().nullable()();

  /// ISO 3166-1 alpha-2 codes.
  TextColumn get nationality => text().nullable()();
  TextColumn get country => text().nullable()();

  TextColumn get source => text().nullable()();
  TextColumn get subSource => text().nullable()();

  /// Leads only.
  TextColumn get statusId => text().nullable().references(LeadStatuses, #id)();

  /// When a lead became a client.
  DateTimeColumn get convertedAt => dateTime().nullable()();
}

/// What a client bought or rented, when and where (many per client).
@DataClassName('Deal')
class Deals extends Table with SyncedTable {
  TextColumn get partyId => text().references(Parties, #id)();
  IntColumn get type => intEnum<DealType>()();

  /// What was bought or rented.
  TextColumn get item => text()();
  DateTimeColumn get date => dateTime()();

  /// Where, e.g. the community or branch.
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// A call, meeting, task, email or lunch, optionally with a lead, client
/// or phone contact.
@DataClassName('Activity')
class Activities extends Table with SyncedTable {
  IntColumn get type => intEnum<ActivityType>()();
  IntColumn get priority => intEnum<ActivityPriority>()();
  TextColumn get title => text()();

  /// Styled note as Quill Delta JSON, and its plain text for search and
  /// previews.
  TextColumn get noteJson => text().nullable()();
  TextColumn get notePlain => text().nullable()();

  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// With a lead or client…
  TextColumn get partyId => text().nullable().references(Parties, #id)();

  /// …or a phone contact. The name is kept in case the contact changes.
  TextColumn get contactId => text().nullable()();
  TextColumn get contactName => text().nullable()();
}

/// Images attached to an activity, stored as files in the app's documents.
@DataClassName('ActivityAttachment')
class ActivityAttachments extends Table with SyncedTable {
  TextColumn get activityId => text().references(Activities, #id)();

  /// File name inside the attachments folder.
  TextColumn get fileName => text()();
}

@DriftDatabase(
  tables: [LeadStatuses, Parties, Deals, Activities, ActivityAttachments],
)
class CrmDatabase extends _$CrmDatabase {
  CrmDatabase(super.executor);

  /// The app's database file, kept on the device.
  CrmDatabase.open() : super(driftDatabase(name: 'contacts_organizer'));

  /// Statuses every new install starts with.
  static const starterStatuses = [('Cold', 0xFF3D8BF5), ('Hot', 0xFFF0544F)];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final (i, (name, color)) in starterStatuses.indexed) {
        await into(leadStatuses).insert(
          LeadStatusesCompanion.insert(name: name, color: color, position: i),
        );
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(activities);
        await m.createTable(activityAttachments);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
