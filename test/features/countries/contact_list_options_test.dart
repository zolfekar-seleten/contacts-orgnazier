import 'package:country_contacts/features/contacts/data/first_seen_store.dart';
import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:country_contacts/features/countries/domain/contact_list_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fixtures.dart';

void main() {
  // UK: Oliver Bennett (mobile), Amelia Clarke (landline + mobile),
  // Emily Johnson (mobile).
  final uk = ContactDirectory.build(
    sampleContacts,
    PhoneClassifier(),
  ).group('GB')!.contacts;

  List<String> names(ContactListOptions options, [Map<String, int>? seen]) =>
      applyListOptions(
        uk,
        countryKey: 'GB',
        options: options,
        firstSeen: seen ?? const {},
      ).map((c) => c.displayName).toList();

  group('filter', () {
    test('mobile keeps contacts with a mobile number there', () {
      expect(names(const ContactListOptions(filter: NumberFilter.mobile)), [
        'Amelia Clarke',
        'Emily Johnson',
        'Oliver Bennett',
      ]);
    });

    test('landline keeps contacts with a non-mobile number there', () {
      expect(names(const ContactListOptions(filter: NumberFilter.landline)), [
        'Amelia Clarke',
      ]);
    });

    test('only looks at numbers from the given country', () {
      // Emily's US number is a fixed-line-or-mobile +1 number; in the UK
      // list only her UK mobile counts.
      final emily = uk.firstWhere((c) => c.id == '4');
      expect(matchesNumberFilter(emily, 'GB', NumberFilter.landline), isFalse);
    });
  });

  group('sort', () {
    test('by first name', () {
      expect(names(const ContactListOptions()), [
        'Amelia Clarke',
        'Emily Johnson',
        'Oliver Bennett',
      ]);
    });

    test('by last name', () {
      expect(names(const ContactListOptions(sort: ContactSort.lastName)), [
        'Oliver Bennett',
        'Amelia Clarke',
        'Emily Johnson',
      ]);
    });

    test('recently added first, older ones by name', () {
      expect(
        names(const ContactListOptions(sort: ContactSort.recentlyAdded), {
          '1': 100,
          '4': 200,
          '2': 0,
        }),
        ['Emily Johnson', 'Oliver Bennett', 'Amelia Clarke'],
      );
    });
  });

  group('FirstSeenStore', () {
    test('treats existing contacts as old and stamps new ones', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FirstSeenStore(await SharedPreferences.getInstance());

      expect(store.sync(['1', '2'], DateTime.utc(2026, 1, 1)), {
        '1': 0,
        '2': 0,
      });
      final later = DateTime.utc(2026, 2, 1);
      expect(store.sync(['1', '2', '3'], later), {
        '1': 0,
        '2': 0,
        '3': later.millisecondsSinceEpoch,
      });
      // Deleted contacts are forgotten.
      expect(store.sync(['3'], DateTime.utc(2026, 3, 1)), {
        '3': later.millisecondsSinceEpoch,
      });
    });
  });
}
