import 'package:country_contacts/features/broadcast/domain/broadcast.dart';
import 'package:country_contacts/features/broadcast/domain/message_template.dart';
import 'package:country_contacts/features/communication/domain/communication_links.dart';
import 'package:country_contacts/features/contacts/domain/app_contact.dart';
import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/device_contact.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

AppContact build(DeviceContact device, {String? region}) =>
    ContactDirectory.build([
      device,
    ], PhoneClassifier(defaultRegion: region)).contactById(device.id)!;

void main() {
  group('names', () {
    test('structured first/last names win over the display name', () {
      final c = build(
        const DeviceContact(
          id: '1',
          displayName: 'Dr. Sam Lee',
          firstName: 'Samuel',
          lastName: 'Lee',
          phones: [DevicePhone(number: '+44 7400 123456')],
        ),
      );
      expect(c.firstName, 'Samuel');
      expect(c.lastName, 'Lee');
    });

    test('falls back to splitting the display name', () {
      final c = build(contact('1', 'Ahmed Al Mansoori', ['+971501234567']));
      expect(c.firstName, 'Ahmed');
      expect(c.lastName, 'Al Mansoori');
    });

    test('a first name without last name means no last name', () {
      final c = build(
        const DeviceContact(
          id: '1',
          displayName: 'Mum Home',
          firstName: 'Mum',
          phones: [DevicePhone(number: '+44 7400 123456')],
        ),
      );
      expect(c.lastName, '');
    });

    test('a number used as display name is not a name', () {
      final c = build(contact('1', '', ['+44 7400 123456']));
      expect(c.displayName, '+44 7400 123456');
      expect(c.firstName, '');
      expect(c.lastName, '');
    });
  });

  group('MessageTemplate.render', () {
    final ahmed = build(contact('1', 'Ahmed Al Mansoori', ['+971501234567']));
    final cher = build(contact('2', 'Cher', ['+447400123456']));

    test('replaces first, last and full name', () {
      expect(
        MessageTemplate.render(
          'Hi {first_name}! Is {last_name} right? {full_name}',
          ahmed,
        ),
        'Hi Ahmed! Is Al Mansoori right? Ahmed Al Mansoori',
      );
    });

    test('is case and whitespace tolerant', () {
      expect(MessageTemplate.render('Hey { FIRST_NAME }', ahmed), 'Hey Ahmed');
    });

    test('tidies spacing when a name part is empty', () {
      expect(
        MessageTemplate.render('Hi {first_name} {last_name}!', cher),
        'Hi Cher!',
      );
      expect(
        MessageTemplate.render('Dear {first_name} {last_name}, hello', cher),
        'Dear Cher, hello',
      );
    });

    test('keeps line breaks and unknown braces', () {
      expect(
        MessageTemplate.render('Hi {first_name}\nSee {you}', ahmed),
        'Hi Ahmed\nSee {you}',
      );
    });

    test('hasTokens', () {
      expect(MessageTemplate.hasTokens('Hi {full_name}'), isTrue);
      expect(MessageTemplate.hasTokens('Hi there'), isFalse);
    });
  });

  group('pickBroadcastPhone', () {
    final emily = build(
      const DeviceContact(
        id: '1',
        displayName: 'Emily',
        phones: [
          DevicePhone(number: '+1 415 555 2671', label: 'Work'),
          DevicePhone(number: '+44 7400 222333', label: 'Mobile'),
          DevicePhone(number: '+44 20 7946 0958', label: 'Home'),
        ],
      ),
    );

    test('prefers the country the selection came from', () {
      final p = pickBroadcastPhone(
        emily,
        BroadcastChannel.whatsApp,
        countryKey: 'US',
      );
      expect(p!.e164, '+14155552671');
    });

    test('otherwise prefers mobile numbers', () {
      final p = pickBroadcastPhone(emily, BroadcastChannel.sms);
      expect(p!.e164, '+447400222333');
    });

    test('prefers mobile ranges over landlines even if mislabelled', () {
      final c = build(
        contact('3', 'Amelia', [
          '+44 20 7946 0958', // London landline, labelled Mobile by fixture
          '+44 7400 654321',
        ]),
      );
      expect(
        pickBroadcastPhone(c, BroadcastChannel.whatsApp)!.e164,
        '+447400654321',
      );
    });

    test('WhatsApp needs an international number, SMS does not', () {
      final local = build(contact('2', 'Omar', ['050 765 4321']));
      expect(pickBroadcastPhone(local, BroadcastChannel.whatsApp), isNull);
      expect(
        pickBroadcastPhone(local, BroadcastChannel.sms)!.raw,
        '050 765 4321',
      );
    });
  });

  test('planBroadcast personalises and reports unreachable contacts', () {
    final contacts = [
      build(contact('1', 'Ahmed Al Mansoori', ['+971501234567'])),
      build(contact('2', 'Omar Haddad', ['050 765 4321'])),
    ];
    final plan = planBroadcast(
      contacts,
      channel: BroadcastChannel.whatsApp,
      template: 'Hi {first_name}',
    );
    expect(plan.items.single.message, 'Hi Ahmed');
    expect(plan.unreachable.single.displayName, 'Omar Haddad');

    final sms = planBroadcast(
      contacts,
      channel: BroadcastChannel.sms,
      template: 'Hi {first_name}',
    );
    expect(sms.items.map((i) => i.message), ['Hi Ahmed', 'Hi Omar']);
  });

  group('smsUri', () {
    test('Android uses ?body=', () {
      expect(
        CommunicationLinks.smsUri(
          '050 765 4321',
          message: 'Hi Omar & co!',
        ).toString(),
        'sms:0507654321?body=Hi%20Omar%20%26%20co!',
      );
    });

    test('iOS uses &body=', () {
      expect(
        CommunicationLinks.smsUri(
          'x',
          e164: '+971501234567',
          message: 'Hi',
          iosStyle: true,
        ).toString(),
        'sms:+971501234567&body=Hi',
      );
    });

    test('no body when the message is blank; null for bad numbers', () {
      expect(
        CommunicationLinks.smsUri('+447400123456').toString(),
        'sms:+447400123456',
      );
      expect(CommunicationLinks.smsUri('12', message: 'x'), isNull);
    });
  });
}
