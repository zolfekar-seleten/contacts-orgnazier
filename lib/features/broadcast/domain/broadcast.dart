import '../../communication/domain/communication_links.dart';
import '../../contacts/domain/app_contact.dart';
import 'message_template.dart';

enum BroadcastChannel {
  whatsApp('WhatsApp'),
  sms('SMS');

  const BroadcastChannel(this.label);
  final String label;
}

enum DeliveryStatus { pending, opened, skipped, failed }

/// One recipient of a broadcast with their personalised message.
class BroadcastItem {
  const BroadcastItem({
    required this.contact,
    required this.phone,
    required this.message,
    this.status = DeliveryStatus.pending,
  });

  final AppContact contact;
  final ClassifiedPhone phone;
  final String message;
  final DeliveryStatus status;

  BroadcastItem withStatus(DeliveryStatus status) => BroadcastItem(
    contact: contact,
    phone: phone,
    message: message,
    status: status,
  );
}

/// Chooses which number of [contact] to message on [channel].
///
/// Prefers numbers from [countryKey] (the screen the selection came from),
/// then mobile numbers (by numbering plan, then by label). WhatsApp requires an international (E.164)
/// number; SMS accepts any dialable number. Returns null when none qualifies.
ClassifiedPhone? pickBroadcastPhone(
  AppContact contact,
  BroadcastChannel channel, {
  String? countryKey,
}) {
  bool eligible(ClassifiedPhone p) => switch (channel) {
    BroadcastChannel.whatsApp =>
      CommunicationLinks.whatsAppNumber(p.e164) != null,
    BroadcastChannel.sms =>
      CommunicationLinks.dialableNumber(p.raw, e164: p.e164) != null,
  };
  int score(ClassifiedPhone p) {
    final label = p.label.toLowerCase();
    final mobileLabel =
        label.contains('mobile') ||
        label.contains('cell') ||
        label.contains('iphone');
    return (p.isMobile ? 4 : 0) +
        (mobileLabel ? 2 : 0) +
        (p.e164 != null ? 1 : 0);
  }

  for (final pool in [
    if (countryKey != null) contact.phonesFor(countryKey),
    contact.phones,
  ]) {
    final candidates = pool.where(eligible).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    if (candidates.isNotEmpty) return candidates.first;
  }
  return null;
}

/// Splits [contacts] into personalised items and contacts that can't be
/// reached on [channel].
({List<BroadcastItem> items, List<AppContact> unreachable}) planBroadcast(
  List<AppContact> contacts, {
  required BroadcastChannel channel,
  required String template,
  String? countryKey,
}) {
  final items = <BroadcastItem>[];
  final unreachable = <AppContact>[];
  for (final contact in contacts) {
    final phone = pickBroadcastPhone(contact, channel, countryKey: countryKey);
    if (phone == null) {
      unreachable.add(contact);
      continue;
    }
    items.add(
      BroadcastItem(
        contact: contact,
        phone: phone,
        message: MessageTemplate.render(template, contact),
      ),
    );
  }
  return (items: items, unreachable: unreachable);
}
