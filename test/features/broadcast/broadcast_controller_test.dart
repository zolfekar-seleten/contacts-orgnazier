import 'package:country_contacts/features/broadcast/domain/broadcast.dart';
import 'package:country_contacts/features/broadcast/presentation/broadcast_providers.dart';
import 'package:country_contacts/features/communication/domain/communication_service.dart';
import 'package:country_contacts/features/contacts/domain/contact_directory.dart';
import 'package:country_contacts/features/contacts/domain/phone_classifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);

  late MockUrlLauncher launcher;
  late ProviderContainer container;

  final directory = ContactDirectory.build([
    contact('1', 'Ahmed Al Mansoori', ['+971501234567']),
    contact('2', 'Priya Sharma', ['+919876543210']),
    contact('3', 'James Miller', ['+16502530000']),
  ], PhoneClassifier());

  List<BroadcastItem> items(BroadcastChannel channel) => planBroadcast(
    directory.contacts,
    channel: channel,
    template: 'Hi {first_name}',
  ).items;

  setUp(() async {
    launcher = MockUrlLauncher();
    container = ProviderContainer(
      overrides: await testOverrides(
        repository: FakeContactsRepository(),
        launcher: launcher,
      ),
    );
    addTearDown(container.dispose);
  });

  BroadcastController controller() =>
      container.read(broadcastProvider.notifier);
  BroadcastSession session() => container.read(broadcastProvider)!;

  test('opens each recipient with their own message, in order', () async {
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    controller().start(
      BroadcastChannel.whatsApp,
      items(BroadcastChannel.whatsApp),
    );

    expect(session().current!.contact.firstName, 'Ahmed');
    expect(await controller().openCurrent(), OpenOutcome.opened);
    verify(
      () => launcher.launchInApp(
        Uri.parse('https://wa.me/971501234567?text=Hi%20Ahmed'),
      ),
    ).called(1);
    expect(session().items.first.status, DeliveryStatus.opened);
    expect(session().current!.contact.firstName, 'James');
  });

  test('skip advances; finishing reports counts', () async {
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    controller().start(
      BroadcastChannel.whatsApp,
      items(BroadcastChannel.whatsApp),
    );

    controller().skipCurrent();
    await controller().openCurrent();
    await controller().openCurrent();

    expect(session().isFinished, isTrue);
    expect(session().count(DeliveryStatus.opened), 2);
    expect(session().count(DeliveryStatus.skipped), 1);
  });

  test('jumping back lets a skipped recipient be retried', () async {
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    controller().start(
      BroadcastChannel.whatsApp,
      items(BroadcastChannel.whatsApp),
    );
    controller().skipCurrent();
    controller().jumpTo(0);
    await controller().openCurrent();
    expect(session().items.first.status, DeliveryStatus.opened);
  });

  test('WhatsApp missing does not advance; web fallback does', () async {
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => false);
    when(() => launcher.launchInBrowser(any())).thenAnswer((_) async => true);
    controller().start(
      BroadcastChannel.whatsApp,
      items(BroadcastChannel.whatsApp),
    );

    expect(await controller().openCurrent(), OpenOutcome.whatsAppMissing);
    expect(session().index, 0);
    expect(session().items.first.status, DeliveryStatus.pending);

    expect(await controller().openCurrent(viaWeb: true), OpenOutcome.opened);
    expect(session().index, 1);
  });

  test('SMS opens the composer with the personalised body', () async {
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    controller().start(BroadcastChannel.sms, items(BroadcastChannel.sms));

    await controller().openCurrent();
    final uri =
        verify(() => launcher.launchInApp(captureAny())).captured.single as Uri;
    expect(uri.scheme, 'sms');
    expect(uri.toString(), contains('+971501234567'));
    expect(uri.toString(), contains('body=Hi%20Ahmed'));
  });

  test('SMS unsupported is reported without advancing', () async {
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => false);
    controller().start(BroadcastChannel.sms, items(BroadcastChannel.sms));
    expect(await controller().openCurrent(), OpenOutcome.unsupported);
    expect(session().index, 0);
    verifyNever(() => launcher.launchInApp(any()));
  });

  test('selection toggles, selects all and exits', () {
    final selection = container.read(selectionProvider.notifier);
    selection.start('1');
    selection.toggle('2');
    expect(container.read(selectionProvider).ids, {'1', '2'});
    selection.toggle('1');
    expect(container.read(selectionProvider).ids, {'2'});
    selection.toggleAll(['1', '2', '3']);
    expect(container.read(selectionProvider).count, 3);
    selection.toggleAll(['1', '2', '3']);
    expect(container.read(selectionProvider).count, 0);
    selection.exit();
    expect(container.read(selectionProvider).active, isFalse);
  });

  test('service: SMS results', () async {
    final service = CommunicationService(launcher, iosStyleSms: true);
    expect(await service.openSms('12'), SmsResult.invalidNumber);
    when(() => launcher.canLaunch(any())).thenAnswer((_) async => true);
    when(() => launcher.launchInApp(any())).thenAnswer((_) async => true);
    expect(
      await service.openSms('050 765 4321', message: 'Hi'),
      SmsResult.composerOpened,
    );
    verify(
      () => launcher.launchInApp(Uri.parse('sms:0507654321&body=Hi')),
    ).called(1);
  });
}
