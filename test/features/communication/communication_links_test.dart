import 'package:country_contacts/features/communication/domain/communication_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('telUri', () {
    test('prefers E.164', () {
      expect(
        CommunicationLinks.telUri('07400 123456', e164: '+447400123456'),
        Uri.parse('tel:+447400123456'),
      );
    });

    test('cleans formatting when only a raw number is known', () {
      expect(
        CommunicationLinks.telUri('(050) 123-4567')?.toString(),
        'tel:0501234567',
      );
    });

    test('rejects numbers that are too short', () {
      expect(CommunicationLinks.telUri('12'), isNull);
      expect(CommunicationLinks.telUri('call me'), isNull);
    });
  });

  group('whatsAppNumber', () {
    test('strips plus, spaces, brackets and hyphens', () {
      expect(
        CommunicationLinks.whatsAppNumber('+44 (20) 7946-0958'),
        '442079460958',
      );
    });

    test('requires an international number', () {
      expect(CommunicationLinks.whatsAppNumber(null), isNull);
      expect(CommunicationLinks.whatsAppNumber('0501234567'), isNull);
      expect(CommunicationLinks.whatsAppNumber('+0501234567'), isNull);
      expect(CommunicationLinks.whatsAppNumber('+12345'), isNull);
      expect(CommunicationLinks.whatsAppNumber('+1234567890123456'), isNull);
    });
  });

  group('whatsAppUri', () {
    test('builds a wa.me link without text', () {
      expect(
        CommunicationLinks.whatsAppUri('+971501234567').toString(),
        'https://wa.me/971501234567',
      );
    });

    test('omits blank messages', () {
      expect(
        CommunicationLinks.whatsAppUri(
          '+971501234567',
          message: '   ',
        ).toString(),
        'https://wa.me/971501234567',
      );
    });

    test('percent-encodes the message', () {
      final uri = CommunicationLinks.whatsAppUri(
        '+447400123456',
        message: 'Hi Sam & Jo! 50% off? #deal\nCall me 👋',
      )!;
      expect(
        uri.toString(),
        'https://wa.me/447400123456?text='
        'Hi%20Sam%20%26%20Jo!%2050%25%20off%3F%20%23deal%0ACall%20me%20'
        '%F0%9F%91%8B',
      );
      expect(uri.toString(), isNot(contains('+')));
      expect(
        Uri.decodeComponent(uri.query.substring('text='.length)),
        'Hi Sam & Jo! 50% off? #deal\nCall me 👋',
      );
    });

    test('returns null for invalid numbers', () {
      expect(CommunicationLinks.whatsAppUri('050 123', message: 'hi'), isNull);
    });
  });
}
