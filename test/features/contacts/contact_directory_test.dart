import 'package:country_contacts/features/contacts/domain/app_contact.dart';
import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  group('ContactDirectory.build', () {
    late ContactDirectory directory;

    setUp(() {
      directory = ContactDirectory.build(sampleContacts, PhoneClassifier());
    });

    test('counts unique contacts and sorts them by name', () {
      expect(directory.totalContacts, 7);
      expect(directory.contacts.first.displayName, 'Ahmed Al Mansoori');
      expect(directory.contacts.last.displayName, 'Priya Sharma');
    });

    test('aggregates countries by count descending, then by name', () {
      expect(directory.countries.map((g) => (g.key, g.count)).toList(), [
        ('GB', 3),
        ('US', 2),
        ('IN', 1), // ties sorted by name: India < United Arab Emirates
        ('AE', 1),
      ]);
    });

    test('a contact with several numbers in one country counts once', () {
      final gb = directory.group('GB')!;
      expect(gb.contacts.where((c) => c.id == '2'), hasLength(1));
    });

    test('a contact with numbers in two countries appears in both', () {
      expect(directory.group('GB')!.contacts.map((c) => c.id), contains('4'));
      expect(directory.group('US')!.contacts.map((c) => c.id), contains('4'));
      expect(directory.contactById('4')!.countryKeys, {'US', 'GB'});
    });

    test('unclassifiable numbers go to Unknown', () {
      expect(directory.unknown.isUnknown, isTrue);
      expect(directory.unknown.country, isNull);
      expect(directory.unknown.contacts.map((c) => c.id), ['7']);
    });

    test('phonesFor filters a contact to one country', () {
      final emily = directory.contactById('4')!;
      expect(emily.phonesFor('GB').single.e164, '+447400222333');
      expect(emily.phonesFor(null), hasLength(2));
    });
  });

  group('duplicates and data integrity', () {
    test('duplicate numbers within a contact are collapsed', () {
      final directory = ContactDirectory.build([
        contact('1', 'Dup', [
          '+44 7400 123456',
          '+447400123456',
          '07400123456',
        ]),
      ], PhoneClassifier(defaultRegion: 'GB'));
      expect(directory.contactById('1')!.phones, hasLength(1));
    });

    test('duplicate contact ids are ignored', () {
      final directory = ContactDirectory.build([
        contact('1', 'A', ['+44 7400 123456']),
        contact('1', 'A', ['+44 7400 123456']),
      ], PhoneClassifier());
      expect(directory.totalContacts, 1);
    });

    test('raw numbers and labels are preserved', () {
      final directory = ContactDirectory.build([
        contact('1', 'A', ['+44 (0) 7400-123456']),
      ], PhoneClassifier());
      final phone = directory.contactById('1')!.phones.single;
      expect(phone.raw, '+44 (0) 7400-123456');
      expect(phone.label, 'Mobile');
      expect(phone.e164, '+447400123456');
    });

    test('contacts without usable numbers are skipped', () {
      final directory = ContactDirectory.build([
        contact('1', 'Blank', ['']),
      ], PhoneClassifier());
      expect(directory.isEmpty, isTrue);
    });

    test('nameless contacts fall back to their number', () {
      final directory = ContactDirectory.build([
        contact('1', '  ', ['+44 7400 123456']),
      ], PhoneClassifier());
      expect(directory.contactById('1')!.displayName, '+44 7400 123456');
    });
  });

  test('initials use first and last name', () {
    final directory = ContactDirectory.build(sampleContacts, PhoneClassifier());
    expect(directory.contactById('5')!.initials, 'AM');
    expect(directory.contactById('6')!.initials, 'PS');
    expect(CountryGroup.unknownKey, 'ZZ');
  });

  test('initials skip punctuation and number-only names', () {
    final directory = ContactDirectory.build([
      contact('1', 'Ahmed Karimi (Work)', ['+44 7400 123456']),
      contact('2', '12345', ['12345']),
    ], PhoneClassifier());
    expect(directory.contactById('1')!.initials, 'AW');
    expect(directory.contactById('2')!.initials, '#');
  });

  test('precomputeClassifications seeds the cache from an isolate', () async {
    final classifier = PhoneClassifier();
    await precomputeClassifications(
      sampleContacts,
      classifier,
      isolateThreshold: 0,
    );
    expect(classifier.cacheSize, 9);
    expect(classifier.isCached('+44 7400 123456', null), isTrue);

    final directory = ContactDirectory.build(sampleContacts, classifier);
    expect(directory.group('GB')!.count, 3);
  });

  group('display numbers', () {
    final directory = ContactDirectory.build([
      contact('1', 'Amelia', ['+44 20 7946 0958', '+44 7400 654321']),
      contact('2', 'Junk', ['+44 20 7946 0000 ext. 42', '12345']),
    ], PhoneClassifier());

    test('uses a compact international format', () {
      final amelia = directory.contactById('1')!;
      expect(amelia.phones.first.display, '+44 20 7946 0958');
      expect(
        directory.contactById('2')!.phones.first.display,
        '+44 20 7946 0000',
      );
    });

    test('unclassified numbers fall back to the raw text', () {
      expect(directory.contactById('2')!.phones.last.display, '12345');
    });

    test('mobile detection uses numbering metadata, not labels', () {
      final amelia = directory.contactById('1')!;
      expect(amelia.phones.first.isMobile, isFalse);
      expect(amelia.phones.last.isMobile, isTrue);
      expect(amelia.primaryPhone()!.e164, '+447400654321');
    });

    test('primary phone respects the country scope', () {
      final emily = ContactDirectory.build([
        contact('4', 'Emily', ['+44 7400 222333', '+1 415 555 2671']),
      ], PhoneClassifier()).contactById('4')!;
      expect(emily.primaryPhone('US')!.e164, '+14155552671');
      expect(emily.primaryPhone()!.e164, '+447400222333');
    });
  });
}
