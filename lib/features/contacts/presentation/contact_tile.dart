import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/action_circle.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../broadcast/presentation/broadcast_providers.dart';
import '../../communication/presentation/communication_flows.dart';
import '../../contact_details/presentation/contact_details_screen.dart';
import '../domain/app_contact.dart';

/// A contact row with quick call / WhatsApp actions. When [countryKey] is
/// given only numbers from that country are shown and offered.
///
/// With [selectable], long-press starts multi-select and taps toggle the
/// contact while selecting.
class ContactTile extends ConsumerWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.countryKey,
    this.selectable = false,
  });

  final AppContact contact;
  final String? countryKey;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = contact.primaryPhone(countryKey);
    final extra = contact.phonesFor(countryKey).length - 1;

    final selecting =
        selectable && ref.watch(selectionProvider.select((s) => s.active));
    final selected = selecting && ref.watch(isSelectedProvider(contact.id));
    final selection = ref.read(selectionProvider.notifier);

    return InkWell(
      onTap: selecting
          ? () => selection.toggle(contact.id)
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ContactDetailsScreen(contactId: contact.id),
              ),
            ),
      onLongPress: selectable && !selecting
          ? () => selection.start(contact.id)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: selected
            ? theme.colorScheme.secondary.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Semantics(
              checked: selecting ? selected : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? _SelectedBadge(key: const ValueKey('on'))
                    : Hero(
                        key: const ValueKey('off'),
                        tag: 'avatar-${contact.id}',
                        child: ContactAvatar(contact: contact, size: 46),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (primary != null)
                    _NumberLine(phone: primary, extra: extra),
                ],
              ),
            ),
            if (selecting)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outline,
              )
            else ...[
              ActionCircle(
                size: 38,
                tooltip: 'Call ${contact.displayName}',
                color: theme.colorScheme.secondary,
                icon: const Icon(Icons.call_rounded),
                onPressed: () => CommunicationFlows.call(
                  context,
                  ref,
                  contact,
                  countryKey: countryKey,
                ),
              ),
              // A third button would squeeze names on narrow phones; SMS is
              // always available on the contact card.
              if (MediaQuery.sizeOf(context).width >= 360) ...[
                const SizedBox(width: 6),
                ActionCircle(
                  size: 38,
                  tooltip: 'SMS ${contact.displayName}',
                  color: AppColors.sms,
                  icon: const Icon(Icons.sms_rounded),
                  onPressed: () => CommunicationFlows.sms(
                    context,
                    ref,
                    contact,
                    countryKey: countryKey,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              ActionCircle(
                size: 38,
                tooltip: 'WhatsApp ${contact.displayName}',
                color: AppColors.whatsApp,
                icon: const WhatsAppIcon(size: 21),
                onPressed: () => CommunicationFlows.whatsApp(
                  context,
                  ref,
                  contact,
                  countryKey: countryKey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Flag, number and "+N" on one line. The number is never truncated: when
/// space is short it scales down a little instead.
class _NumberLine extends StatelessWidget {
  const _NumberLine({required this.phone, required this.extra});

  final ClassifiedPhone phone;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final flag = phone.country?.flag;
    return Row(
      children: [
        if (flag != null) ...[
          Text(flag, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              phone.display,
              key: const Key('tile-number'),
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$extra',
              semanticsLabel: '$extra more numbers',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.secondary,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
    );
  }
}
