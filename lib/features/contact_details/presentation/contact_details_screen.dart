import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/action_circle.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/flag_badge.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/state_view.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../communication/presentation/communication_flows.dart';
import '../../contacts/domain/app_contact.dart';
import '../../contacts/domain/contacts_repository.dart';
import '../../contacts/domain/phone_classification.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../local_time/presentation/local_time_widgets.dart';

class ContactDetailsScreen extends ConsumerWidget {
  const ContactDetailsScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactByIdProvider(contactId));
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const StateView(
          icon: Icons.person_off_outlined,
          title: 'Contact unavailable',
          message: 'This contact was removed or no longer has phone numbers.',
        ),
      );
    }
    final theme = Theme.of(context);
    final countries = {
      for (final p in contact.phones)
        if (p.country != null) p.country!,
    };
    final padding = contentPadding(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          TextButton.icon(
            key: const Key('details-edit'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
            onPressed: () => _edit(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Gradient backdrop with the avatar overlapping its lower edge.
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 196,
                  decoration: BoxDecoration(
                    gradient: AppColors.hero(theme.brightness),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Hero(
                    tag: 'avatar-$contactId',
                    child: ContactAvatar(
                      contact: contact,
                      size: 112,
                      ring: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: padding.copyWith(top: 14, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  contact.displayName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in countries)
                      _Pill(
                        leading: Text(c.flag),
                        label: '${c.name} ${c.formattedDialCode}',
                      ),
                    if (countries.isEmpty)
                      const _Pill(
                        leading: Icon(Icons.public_rounded, size: 16),
                        label: 'Unknown country',
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    LabeledAction(
                      key: const Key('details-call'),
                      icon: const Icon(Icons.call_rounded),
                      label: 'Call',
                      background: dark ? AppColors.accent : AppColors.navy,
                      foreground: Colors.white,
                      onPressed: () =>
                          CommunicationFlows.call(context, ref, contact),
                    ),
                    LabeledAction(
                      key: const Key('details-sms'),
                      icon: const Icon(Icons.sms_rounded),
                      label: 'SMS',
                      background: AppColors.sms,
                      foreground: Colors.white,
                      onPressed: () =>
                          CommunicationFlows.sms(context, ref, contact),
                    ),
                    LabeledAction(
                      key: const Key('details-whatsapp'),
                      icon: const WhatsAppIcon(size: 28, color: Colors.white),
                      label: 'WhatsApp',
                      background: AppColors.whatsApp,
                      foreground: Colors.white,
                      onPressed: () =>
                          CommunicationFlows.whatsApp(context, ref, contact),
                    ),
                  ],
                ),
                SectionHeader(
                  contact.phones.length == 1 ? 'Phone' : 'Phones',
                  trailing: '${contact.phones.length}',
                ),
                for (var i = 0; i < contact.phones.length; i++)
                  GroupedListItem(
                    index: i,
                    count: contact.phones.length,
                    child: _PhoneRow(
                      contact: contact,
                      phone: contact.phones[i],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Long-press a number to copy it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Contacts Organizer never changes your address book '
                        'itself. Edits are made and saved in your phone’s '
                        'Contacts app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(contactsControllerProvider.notifier)
        .editInSystemApp(contactId);
    if (!context.mounted) return;
    final message = switch (result) {
      ContactEditResult.saved => 'Contact updated.',
      ContactEditResult.cancelled => null,
      ContactEditResult.unavailable => 'Couldn’t open the contacts editor.',
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.leading, required this.label});

  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneRow extends ConsumerWidget {
  const _PhoneRow({required this.contact, required this.phone});

  final AppContact contact;
  final ClassifiedPhone phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final country = phone.country;
    final detail = country != null
        ? '${country.name}  ·  ${country.formattedDialCode}'
        : switch (phone.classification.reason) {
            UnknownReason.ambiguousNationalFormat =>
              'Unknown country · no country code',
            UnknownReason.invalid => 'Unknown country · not a valid number',
            _ => 'Unknown country',
          };
    final international = phone.e164;

    final warning = country == null;
    final warningColor = theme.brightness == Brightness.dark
        ? const Color(0xFFFFC870)
        : const Color(0xFFB26A00);

    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: international ?? phone.raw));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Copied ${international ?? phone.raw}')),
          );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            FlagBadge(country: country, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phone.label.isNotEmpty)
                    Text(
                      phone.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    phone.raw,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (international != null &&
                      international != phone.raw.replaceAll(' ', ''))
                    Text(
                      international,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (warning) ...[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: warningColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: warning
                                ? warningColor
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (country != null) ...[
                    const SizedBox(height: 2),
                    LocalTimeLabel(isoCode: country.isoCode),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            ActionCircle(
              tooltip: 'Call ${phone.raw}',
              color: scheme.secondary,
              icon: const Icon(Icons.call_rounded),
              onPressed: () =>
                  CommunicationFlows.call(context, ref, contact, phone: phone),
            ),
            const SizedBox(width: 6),
            ActionCircle(
              tooltip: 'SMS ${phone.raw}',
              color: AppColors.sms,
              icon: const Icon(Icons.sms_rounded),
              onPressed: () =>
                  CommunicationFlows.sms(context, ref, contact, phone: phone),
            ),
            const SizedBox(width: 6),
            ActionCircle(
              tooltip: 'WhatsApp ${phone.raw}',
              color: AppColors.whatsApp,
              icon: const WhatsAppIcon(size: 21),
              onPressed: () => CommunicationFlows.whatsApp(
                context,
                ref,
                contact,
                phone: phone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
