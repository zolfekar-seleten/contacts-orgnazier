import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/flag_badge.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../contacts/domain/app_contact.dart';
import '../domain/communication_kind.dart';
import '../domain/communication_links.dart';
import '../domain/communication_service.dart';
import 'communication_providers.dart';
import 'message_composer_sheet.dart';

/// UI orchestration for calling / messaging: choose a number, confirm, launch,
/// and report the outcome. Platform work lives in [CommunicationService].
class CommunicationFlows {
  const CommunicationFlows._();

  static Future<void> call(
    BuildContext context,
    WidgetRef ref,
    AppContact contact, {
    ClassifiedPhone? phone,
    String? countryKey,
  }) async {
    phone ??= await _pickPhone(
      context,
      contact,
      contact.phonesFor(countryKey),
      CommunicationKind.call,
    );
    if (phone == null || !context.mounted) return;

    final result = await ref
        .read(communicationServiceProvider)
        .call(phone.raw, e164: phone.e164);
    if (!context.mounted) return;
    final message = switch (result) {
      CallResult.dialerOpened => null,
      CallResult.invalidNumber => 'This number can’t be dialled.',
      CallResult.unsupported => 'This device can’t make phone calls.',
      CallResult.failed => 'Couldn’t open the phone app.',
    };
    if (message != null) _snack(context, message);
  }

  static Future<void> whatsApp(
    BuildContext context,
    WidgetRef ref,
    AppContact contact, {
    ClassifiedPhone? phone,
    String? countryKey,
  }) async {
    if (phone == null) {
      final eligible = contact
          .phonesFor(countryKey)
          .where((p) => p.e164 != null)
          .toList();
      if (eligible.isEmpty) {
        _snack(
          context,
          'WhatsApp needs a number with a country code. '
          'Set a default region in Settings or edit the number.',
        );
        return;
      }
      phone = await _pickPhone(
        context,
        contact,
        eligible,
        CommunicationKind.whatsApp,
      );
    } else if (phone.e164 == null) {
      _snack(context, 'WhatsApp needs a number with a country code.');
      return;
    }
    if (phone == null || !context.mounted) return;

    final message = await showMessageComposer(
      context,
      contact: contact,
      phone: phone,
    );
    if (message == null || !context.mounted) return;

    final service = ref.read(communicationServiceProvider);
    final result = await service.openWhatsApp(phone.e164, message: message);
    if (!context.mounted) return;
    switch (result) {
      case WhatsAppResult.appOpened:
        _snack(context, 'WhatsApp opened. Review and send your message there.');
      case WhatsAppResult.invalidNumber:
        _snack(context, 'This number isn’t valid for WhatsApp.');
      case WhatsAppResult.notInstalled || WhatsAppResult.failed:
        final useWeb = await _confirmWebFallback(context);
        if (useWeb != true || !context.mounted) return;
        final web = await service.openWhatsAppWeb(phone.e164, message: message);
        if (!context.mounted) return;
        _snack(
          context,
          web == WhatsAppResult.webOpened
              ? 'Opened WhatsApp in your browser.'
              : 'Couldn’t open WhatsApp.',
        );
      case WhatsAppResult.webOpened:
        break;
    }
  }

  static Future<void> sms(
    BuildContext context,
    WidgetRef ref,
    AppContact contact, {
    ClassifiedPhone? phone,
    String? countryKey,
  }) async {
    // Any dialable number works for SMS, including local formats.
    bool dialable(ClassifiedPhone p) =>
        CommunicationLinks.dialableNumber(p.raw, e164: p.e164) != null;
    if (phone == null) {
      final eligible = contact.phonesFor(countryKey).where(dialable).toList();
      if (eligible.isEmpty) {
        _snack(context, 'This contact has no number that can receive SMS.');
        return;
      }
      phone = await _pickPhone(
        context,
        contact,
        eligible,
        CommunicationKind.sms,
      );
    } else if (!dialable(phone)) {
      _snack(context, 'This number can’t receive SMS.');
      return;
    }
    if (phone == null || !context.mounted) return;

    final message = await showMessageComposer(
      context,
      contact: contact,
      phone: phone,
      kind: CommunicationKind.sms,
    );
    if (message == null || !context.mounted) return;

    final result = await ref
        .read(communicationServiceProvider)
        .openSms(phone.raw, e164: phone.e164, message: message);
    if (!context.mounted) return;
    _snack(context, switch (result) {
      SmsResult.composerOpened =>
        'Messages opened. Review and send your message there.',
      SmsResult.unsupported => 'This device can’t send text messages.',
      SmsResult.invalidNumber => 'This number can’t receive SMS.',
      SmsResult.failed => 'Couldn’t open Messages.',
    });
  }

  static Future<bool?> _confirmWebFallback(BuildContext context) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const WhatsAppIcon(size: 36),
          title: const Text('WhatsApp isn’t available'),
          content: const Text(
            'WhatsApp doesn’t seem to be installed on this device. You can '
            'continue in your browser with WhatsApp Web instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open WhatsApp Web'),
            ),
          ],
        ),
      );

  static Future<ClassifiedPhone?> _pickPhone(
    BuildContext context,
    AppContact contact,
    List<ClassifiedPhone> phones,
    CommunicationKind kind,
  ) async {
    if (phones.isEmpty) return null;
    if (phones.length == 1) return phones.single;
    return showModalBottomSheet<ClassifiedPhone>(
      context: context,
      useSafeArea: true,
      builder: (context) =>
          PhonePickerSheet(contact: contact, phones: phones, kind: kind),
    );
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class PhonePickerSheet extends StatelessWidget {
  const PhonePickerSheet({
    super.key,
    required this.contact,
    required this.phones,
    required this.kind,
  });

  final AppContact contact;
  final List<ClassifiedPhone> phones;
  final CommunicationKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(switch (kind) {
            CommunicationKind.call => 'Call ${contact.displayName}',
            CommunicationKind.sms => 'Text ${contact.displayName}',
            CommunicationKind.whatsApp => 'Message ${contact.displayName}',
          }, style: theme.textTheme.titleMedium),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: phones.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, i) {
              final phone = phones[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: FlagBadge(country: phone.country, size: 36),
                title: Text(phone.raw),
                subtitle: Text(
                  [
                    if (phone.label.isNotEmpty) phone.label,
                    phone.country?.name ?? 'Unknown country',
                  ].join(' · '),
                ),
                trailing: switch (kind) {
                  CommunicationKind.call => const Icon(Icons.call_rounded),
                  CommunicationKind.sms => const Icon(Icons.sms_rounded),
                  CommunicationKind.whatsApp => const WhatsAppIcon(),
                },
                onTap: () => Navigator.pop(context, phone),
              );
            },
          ),
        ),
      ],
    );
  }
}
