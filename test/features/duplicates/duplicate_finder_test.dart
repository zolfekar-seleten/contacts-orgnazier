import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/device_contact.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:country_contacts/features/duplicates/domain/duplicate_finder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

DuplicateReport report(List<DeviceContact> contacts) => findDuplicates(
  ContactDirectory.build(
    contacts,
    PhoneClassifier(defaultRegion: 'GB'),
  ).contacts,
);

void main() {
  test('finds no duplicates in distinct contacts', () {
    final r = report(sampleContacts);
    expect(r.isEmpty, isTrue);
    expect(r.contactCount, 0);
  });

  test('matches the same number written in different formats', () {
    final r = report([
      contact('1', 'Oliver Bennett', ['+44 7400 123456']),
      contact('2', 'Olly B', ['07400 123456']),
      contact('3', 'O. Bennett (work)', ['0044 7400 123456']),
      contact('4', 'Someone Else', ['+44 7400 999999']),
    ]);

    expect(r.groups, hasLength(1));
    final g = r.groups.single;
    expect(g.reason, DuplicateReason.samePhone);
    expect(g.key, '+447400123456');
    expect(g.contacts.map((c) => c.id), ['3', '1', '2']);
    expect(g.title, '+44 7400 123456');
    expect(r.contactCount, 3);
  });

  test('matches identical names regardless of case and spacing', () {
    final r = report([
      contact('1', 'Sara Khan', ['+971 50 123 4567']),
      contact('2', '  sara   KHAN ', ['+971 50 765 4321']),
      contact('3', 'Sarah Khan', ['+971 50 111 2222']),
    ]);

    expect(r.groups.single.reason, DuplicateReason.sameName);
    expect(r.groups.single.contacts.map((c) => c.id).toSet(), {'1', '2'});
  });

  test('skips a name group that repeats a phone group', () {
    final r = report([
      contact('1', 'Sara Khan', ['+971 50 123 4567']),
      contact('2', 'Sara Khan', ['+971 50 123 4567']),
    ]);

    expect(r.groups.single.reason, DuplicateReason.samePhone);
  });

  test('ignores short service codes and names without letters', () {
    final r = report([
      contact('1', '12345', ['12345']),
      contact('2', '12345', ['12345']),
    ]);

    expect(r.isEmpty, isTrue);
  });

  test('counts each contact once across groups', () {
    final r = report([
      contact('1', 'Ali', ['+44 7400 111111', '+44 7400 222222']),
      contact('2', 'Ali Hassan', ['+44 7400 111111']),
      contact('3', 'Ali H', ['+44 7400 222222']),
    ]);

    expect(r.byPhone, hasLength(2));
    expect(r.contactCount, 3);
  });
}
