import 'package:country_contacts/features/communication/domain/communication_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

void main() {
  late MockUrlLauncher launcher;
  late CommunicationService service;

  setUpAll(registerFallbacks);
  setUp(() {
    launcher = MockUrlLauncher();
    service = CommunicationService(launcher);
  });

  group('call', () {
    test('opens the dialer with the E.164 tel: URI', () async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);

      final result = await service.call('07400 123456', e164: '+447400123456');

      expect(result, CallResult.dialerOpened);
      verify(
        () => launcher.launchInApp(Uri.parse('tel:+447400123456')),
      ).called(1);
    });

    test('reports devices that cannot call', () async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => false);
      expect(await service.call('+447400123456'), CallResult.unsupported);
      verifyNever(() => launcher.launchInApp(any()));
    });

    test('rejects invalid numbers without touching the platform', () async {
      expect(await service.call('12'), CallResult.invalidNumber);
      verifyZeroInteractions(launcher);
    });

    test('reports launch failures', () async {
      when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
      when(
        () => launcher.launchInApp(any()),
      ).thenThrow(PlatformException(code: 'ACTIVITY_NOT_FOUND'));
      expect(await service.call('+447400123456'), CallResult.failed);
    });
  });

  group('openWhatsApp', () {
    test('opens WhatsApp with an encoded prefilled message', () async {
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);

      final result = await service.openWhatsApp(
        '+971501234567',
        message: 'Hello there',
      );

      expect(result, WhatsAppResult.appOpened);
      verify(
        () => launcher.launchInApp(
          Uri.parse('https://wa.me/971501234567?text=Hello%20there'),
        ),
      ).called(1);
      verifyNever(() => launcher.launchInBrowser(any()));
    });

    test('reports WhatsApp not installed', () async {
      when(() => launcher.launchInApp(any())).thenAnswer((_) async => false);
      expect(
        await service.openWhatsApp('+971501234567'),
        WhatsAppResult.notInstalled,
      );
    });

    test('rejects numbers without a country code', () async {
      expect(
        await service.openWhatsApp('0501234567'),
        WhatsAppResult.invalidNumber,
      );
      expect(await service.openWhatsApp(null), WhatsAppResult.invalidNumber);
      verifyZeroInteractions(launcher);
    });

    test('falls back to WhatsApp Web in the browser', () async {
      when(() => launcher.launchInBrowser(any())).thenAnswer((_) async => true);
      expect(
        await service.openWhatsAppWeb('+971501234567', message: 'Hi'),
        WhatsAppResult.webOpened,
      );
      verify(
        () => launcher.launchInBrowser(
          Uri.parse('https://wa.me/971501234567?text=Hi'),
        ),
      ).called(1);
    });

    test('reports web fallback failure', () async {
      when(
        () => launcher.launchInBrowser(any()),
      ).thenAnswer((_) async => false);
      expect(
        await service.openWhatsAppWeb('+971501234567'),
        WhatsAppResult.failed,
      );
    });
  });
}
