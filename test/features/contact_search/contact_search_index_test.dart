import 'package:country_contacts/features/contact_search/domain/contact_search_index.dart';
import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  final index = ContactSearchIndex(
    ContactDirectory.build(sampleContacts, PhoneClassifier()),
  );
  List<String> names(String q, {String? country}) => index
      .searchContacts(q, countryKey: country)
      .map((c) => c.displayName)
      .toList();

  group('searchContacts', () {
    test('empty query returns everything in scope', () {
      expect(names(''), hasLength(7));
      expect(names('  ', country: 'US'), hasLength(2));
    });

    test('matches names case-insensitively', () {
      expect(names('oliv'), ['Oliver Bennett']);
      expect(names('JOHN'), ['Emily Johnson']);
    });

    test('matches phone digits ignoring formatting', () {
      expect(names('7946 0958'), ['Amelia Clarke']);
      expect(names('(650) 253'), ['James Miller']);
    });

    test('matches international and national forms', () {
      expect(names('+97150'), ['Ahmed Al Mansoori']);
      expect(names('971501234567'), ['Ahmed Al Mansoori']);
    });

    test('matches by country name or ISO code', () {
      expect(names('india'), ['Priya Sharma']);
      expect(names('united states'), ['Emily Johnson', 'James Miller']);
    });

    test('respects the country scope', () {
      expect(names('emily', country: 'GB'), ['Emily Johnson']);
      expect(names('james', country: 'GB'), isEmpty);
      expect(names('', country: 'ZZ'), ['Mystery Number']);
    });

    test('returns nothing for unknown text', () {
      expect(names('zzzz'), isEmpty);
    });
  });

  group('searchCountries', () {
    List<String> keys(String q) =>
        index.searchCountries(q).map((g) => g.key).toList();

    test('by name', () => expect(keys('king'), ['GB']));
    test('by ISO code', () => expect(keys('ae'), ['AE']));
    test('by dialing code with or without plus', () {
      expect(keys('+44'), ['GB']);
      expect(keys('91'), ['IN']);
      expect(keys('+1'), ['US']);
    });
    test(
      'empty query returns all countries',
      () => expect(keys(''), hasLength(4)),
    );
  });
}
