import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/device_contact.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:country_contacts/features/export/domain/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

List<String> lines(String csv) {
  expect(csv.startsWith('﻿'), isTrue, reason: 'UTF-8 BOM for Excel');
  expect(csv.endsWith('\r\n'), isTrue);
  return csv.substring(1).split('\r\n')..removeLast();
}

void main() {
  final directory = ContactDirectory.build(sampleContacts, PhoneClassifier());

  test('writes a header and one row per number of the country', () {
    final emily = directory.contactById('4')!;
    final amelia = directory.contactById('2')!;
    final rows = lines(contactsToCsv([amelia, emily], countryKey: 'GB'));

    expect(rows.first, csvHeader.join(','));
    expect(rows.skip(1), [
      'Amelia,Clarke,Amelia Clarke,"\t+442079460958",'
          '"\t+44 20 7946 0958",Mobile,United Kingdom,"\t+44"',
      'Amelia,Clarke,Amelia Clarke,"\t+447400654321",'
          '"\t+44 7400 654321",Mobile,United Kingdom,"\t+44"',
      'Emily,Johnson,Emily Johnson,"\t+447400222333",'
          '"\t+44 7400 222333",Mobile,United Kingdom,"\t+44"',
    ]);
  });

  test('exports every number without a country filter', () {
    final emily = directory.contactById('4')!;
    expect(lines(contactsToCsv([emily])), hasLength(3));
  });

  test('quotes commas and quotes, and defuses formulas in names', () {
    final contacts = ContactDirectory.build([
      const DeviceContact(
        id: '1',
        displayName: 'Smith, "Jo"',
        firstName: '=HYPERLINK("x")',
        phones: [DevicePhone(number: '12345', label: 'Home')],
      ),
    ], PhoneClassifier()).contacts;
    final row = lines(contactsToCsv(contacts))[1];

    expect(row, startsWith('"\t=HYPERLINK(""x"")",,"Smith, ""Jo""",12345,'));
    expect(row, endsWith(',Home,Unknown,'));
  });

  test('file name carries the scope and date without unsafe characters', () {
    expect(
      csvFileName('Côte d’Ivoire / Test', DateTime(2026, 3, 7)),
      'Contacts Organizer - Côte d’Ivoire  Test - 2026-03-07.csv',
    );
  });
}
