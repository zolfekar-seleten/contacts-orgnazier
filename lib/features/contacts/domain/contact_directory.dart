import 'dart:isolate';

import 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

import 'app_contact.dart';
import 'device_contact.dart';
import 'phone_classification.dart';
import 'phone_classifier.dart';

/// Immutable, pre-aggregated view of all contacts grouped by country.
class ContactDirectory {
  ContactDirectory._({
    required this.contacts,
    required this.countries,
    required this.unknown,
  }) : _byId = {for (final c in contacts) c.id: c},
       _byKey = {
         for (final g in countries) g.key: g,
         CountryGroup.unknownKey: unknown,
       };

  static final empty = ContactDirectory._(
    contacts: const [],
    countries: const [],
    unknown: const CountryGroup(key: CountryGroup.unknownKey, contacts: []),
  );

  /// All contacts with at least one phone number, sorted by name.
  final List<AppContact> contacts;

  /// Country groups sorted by contact count (descending), then name.
  final List<CountryGroup> countries;

  /// Contacts with at least one number that could not be classified.
  final CountryGroup unknown;

  final Map<String, AppContact> _byId;
  final Map<String, CountryGroup> _byKey;

  int get totalContacts => contacts.length;

  /// Distinct phone numbers across all contacts.
  late final int totalNumbers = contacts.fold(
    0,
    (sum, c) => sum + c.phones.length,
  );
  bool get isEmpty => contacts.isEmpty;

  AppContact? contactById(String id) => _byId[id];
  CountryGroup? group(String key) => _byKey[key];

  /// Builds a directory from raw device contacts.
  ///
  /// Each contact is counted at most once per country even if it has several
  /// numbers there. Duplicate numbers within a contact (same E.164, or same
  /// raw string) are collapsed.
  factory ContactDirectory.build(
    List<DeviceContact> source,
    PhoneClassifier classifier,
  ) {
    final contacts = <AppContact>[];
    final seenIds = <String>{};
    for (final device in source) {
      if (!seenIds.add(device.id)) continue;
      final phones = <ClassifiedPhone>[];
      final seenNumbers = <String>{};
      for (final phone in device.phones) {
        final classification = classifier.classify(
          phone.number,
          platformNormalized: phone.platformNormalized,
        );
        final dedupeKey =
            classification.e164 ?? normalizePhoneInput(phone.number);
        if (dedupeKey.isEmpty || !seenNumbers.add(dedupeKey)) continue;
        phones.add(
          ClassifiedPhone(
            raw: phone.number,
            label: phone.label,
            classification: classification,
          ),
        );
      }
      if (phones.isEmpty) continue;
      contacts.add(
        AppContact(
          id: device.id,
          displayName: device.displayName.trim().isEmpty
              ? phones.first.raw
              : device.displayName.trim(),
          phones: phones,
          thumbnail: device.thumbnail,
          firstName: device.firstName,
          lastName: device.lastName,
        ),
      );
    }
    contacts.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    final buckets = <String, List<AppContact>>{};
    for (final contact in contacts) {
      for (final key in contact.countryKeys) {
        (buckets[key] ??= []).add(contact);
      }
    }
    final unknownContacts = buckets.remove(CountryGroup.unknownKey) ?? [];
    final countries =
        [
          for (final e in buckets.entries)
            CountryGroup(key: e.key, contacts: e.value),
        ]..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          return (a.country?.name ?? a.key).compareTo(b.country?.name ?? b.key);
        });

    return ContactDirectory._(
      contacts: contacts,
      countries: countries,
      unknown: CountryGroup(
        key: CountryGroup.unknownKey,
        contacts: unknownContacts,
      ),
    );
  }
}

/// Classifies all not-yet-cached numbers of [contacts] in a background
/// isolate when there are enough of them to risk jank, then seeds [classifier]
/// so that [ContactDirectory.build] is a cheap cache lookup.
Future<void> precomputeClassifications(
  List<DeviceContact> contacts,
  PhoneClassifier classifier, {
  int isolateThreshold = 300,
}) async {
  final pending = <(String, String?)>{};
  for (final c in contacts) {
    for (final p in c.phones) {
      if (!classifier.isCached(p.number, p.platformNormalized)) {
        pending.add((p.number, p.platformNormalized));
      }
    }
  }
  if (pending.length < isolateThreshold) return;

  classifier.putAll(
    await _classifyInIsolate(pending.toList(), classifier.defaultRegion),
  );
}

// Kept top-level so the isolate closure captures only plain inputs, not
// contact thumbnails from the caller's scope.
Future<Map<String, PhoneClassification>> _classifyInIsolate(
  List<(String, String?)> inputs,
  IsoCode? region,
) => Isolate.run(
  () => {
    for (final (raw, normalized) in inputs)
      PhoneClassifier.cacheKey(
        raw,
        normalized,
      ): PhoneClassifier.classifyUncached(
        raw,
        platformNormalized: normalized,
        defaultRegion: region,
      ),
  },
);
