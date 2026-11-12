import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/action_circle.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/state_view.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../communication/domain/communication_kind.dart';
import '../../communication/domain/communication_service.dart';
import '../../communication/presentation/communication_providers.dart';
import '../../local_time/presentation/local_time_widgets.dart';
import '../data/crm_database.dart';
import '../domain/party_phone.dart';
import 'crm_providers.dart';
import 'crm_widgets.dart';
import 'deal_form_sheet.dart';
import 'party_form_screen.dart';

class PartyDetailScreen extends ConsumerWidget {
  const PartyDetailScreen({super.key, required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(partyProvider(partyId));
    final party = async.value;
    if (party == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const StateView(
                icon: Icons.person_off_outlined,
                title: 'Not found',
                message: 'This record was deleted.',
              ),
      );
    }
    final theme = Theme.of(context);
    final padding = contentPadding(context);
    final lead = party.kind == PartyKind.lead;
    final statuses = ref.watch(leadStatusesProvider).value ?? const [];
    final status = statuses.where((s) => s.id == party.statusId).firstOrNull;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('party-edit'),
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PartyFormScreen(kind: party.kind, party: party),
              ),
            ),
          ),
          PopupMenuButton<void>(
            key: const Key('party-more'),
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('party-delete'),
                onTap: () => _delete(context, ref, party),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: padding.copyWith(top: 0, bottom: 40),
        children: [
          Center(child: PartyAvatar(party: party, size: 88)),
          const SizedBox(height: 12),
          Text(
            party.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Center(
            child: lead
                ? (status == null
                      ? const SizedBox.shrink()
                      : StatusPill(
                          key: const Key('detail-status'),
                          status: status,
                          onTap: () => _changeStatus(context, ref, party),
                        ))
                : Text(
                    party.convertedAt == null
                        ? 'Client since ${formatDate(context, party.createdAt)}'
                        : 'Client since '
                              '${formatDate(context, party.convertedAt!)} · '
                              'was a lead',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (party.e164 != null) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 8,
              children: [
                LabeledAction(
                  key: const Key('party-call'),
                  icon: const Icon(Icons.call_rounded),
                  label: 'Call',
                  background: dark ? AppColors.accent : AppColors.navy,
                  foreground: Colors.white,
                  onPressed: () =>
                      _contact(context, ref, party, CommunicationKind.call),
                ),
                LabeledAction(
                  key: const Key('party-sms'),
                  icon: const Icon(Icons.sms_rounded),
                  label: 'SMS',
                  background: AppColors.sms,
                  foreground: Colors.white,
                  onPressed: () =>
                      _contact(context, ref, party, CommunicationKind.sms),
                ),
                LabeledAction(
                  key: const Key('party-whatsapp'),
                  icon: const WhatsAppIcon(size: 28, color: Colors.white),
                  label: 'WhatsApp',
                  background: AppColors.whatsApp,
                  foreground: Colors.white,
                  onPressed: () =>
                      _contact(context, ref, party, CommunicationKind.whatsApp),
                ),
              ],
            ),
          ],
          if (lead) ...[
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              key: const Key('convert-client'),
              onPressed: () => _convert(context, ref, party),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Convert to client'),
            ),
          ],
          const SectionHeader('Details'),
          ..._details(context, party),
          if (!lead) _Deals(partyId: party.id),
        ],
      ),
    );
  }

  List<Widget> _details(BuildContext context, Party p) {
    final rows = <(IconData, String, String, Widget?)>[
      if (p.phoneDisplay != null)
        (
          Icons.phone_iphone_rounded,
          'Mobile',
          p.phoneDisplay!,
          LocalTimeLabel(isoCode: p.phoneRegion),
        ),
      if (p.nationalityCountry case final c?)
        (Icons.flag_outlined, 'Nationality', '${c.flag}  ${c.name}', null),
      if (p.residenceCountry case final c?)
        (Icons.public_rounded, 'Country', '${c.flag}  ${c.name}', null),
      if (p.source != null)
        (Icons.campaign_outlined, 'Source', p.source!, null),
      if (p.subSource != null)
        (
          Icons.subdirectory_arrow_right_rounded,
          'Sub source',
          p.subSource!,
          null,
        ),
      (Icons.event_outlined, 'Added', formatDate(context, p.createdAt), null),
    ];
    return [
      for (final (i, (icon, label, value, extra)) in rows.indexed)
        GroupedListItem(
          index: i,
          count: rows.length,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
                ?extra,
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    Party party,
    CommunicationKind kind,
  ) async {
    final e164 = party.e164!;
    final ok = await confirmLateNight(
      context,
      ref,
      isoCode: party.phoneRegion,
      name: party.name.split(' ').first,
      kind: kind,
    );
    if (!ok || !context.mounted) return;
    final service = ref.read(communicationServiceProvider);
    final String? problem = switch (kind) {
      CommunicationKind.call => switch (await service.call(e164, e164: e164)) {
        CallResult.dialerOpened => null,
        CallResult.invalidNumber => 'This number can’t be dialled.',
        CallResult.unsupported => 'This device can’t make phone calls.',
        CallResult.failed => 'Couldn’t open the phone app.',
      },
      CommunicationKind.sms => switch (await service.openSms(
        e164,
        e164: e164,
      )) {
        SmsResult.composerOpened => null,
        SmsResult.unsupported => 'This device can’t send text messages.',
        SmsResult.invalidNumber => 'This number can’t receive SMS.',
        SmsResult.failed => 'Couldn’t open Messages.',
      },
      CommunicationKind.whatsApp => switch (await service.openWhatsApp(e164)) {
        WhatsAppResult.appOpened || WhatsAppResult.webOpened => null,
        WhatsAppResult.invalidNumber => 'This number isn’t valid for WhatsApp.',
        _ => 'WhatsApp isn’t installed on this device.',
      },
    };
    if (problem != null && context.mounted) _snack(context, problem);
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Party party,
  ) async {
    final statuses = ref.read(leadStatusesProvider).value ?? const [];
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final s in statuses)
            ListTile(
              key: ValueKey('pick-status-${s.name}'),
              leading: CircleAvatar(backgroundColor: Color(s.color), radius: 8),
              title: Text(s.name),
              trailing: s.id == party.statusId
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, s.id),
            ),
        ],
      ),
    );
    if (picked == null || picked == party.statusId) return;
    await ref
        .read(crmRepositoryProvider)
        .updateParty(party.id, PartiesCompanion(statusId: Value(picked)));
  }

  Future<void> _convert(
    BuildContext context,
    WidgetRef ref,
    Party party,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Convert ${party.name} to a client?'),
        content: const Text(
          'They move to the Clients tab with all their details, where you '
          'can record what they bought or rented.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('convert-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(crmRepositoryProvider).convertToClient(party.id);
    if (context.mounted) _snack(context, '${party.name} is now a client.');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Party party) async {
    final noun = party.kind == PartyKind.lead ? 'lead' : 'client';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${party.name}?'),
        content: Text(
          'This removes the $noun'
          '${party.kind == PartyKind.client ? ' and their purchases' : ''} '
          'from Contacts Organizer. Your phone’s contacts are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(crmRepositoryProvider).deleteParty(party.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}

/// "Purchases & rentals" for a client.
class _Deals extends ConsumerWidget {
  const _Deals({required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deals = ref.watch(dealsProvider(partyId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Purchases & rentals',
          trailing: '${deals.length}',
          action: TextButton.icon(
            key: const Key('add-deal'),
            onPressed: () => showDealForm(context, partyId: partyId),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (deals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nothing recorded yet. Add what this client bought or rented, '
              'when and where.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final (i, d) in deals.indexed)
          GroupedListItem(
            key: ValueKey(d.id),
            index: i,
            count: deals.length,
            child: ListTile(
              onTap: () => showDealForm(context, partyId: partyId, deal: d),
              leading: CircleAvatar(
                backgroundColor:
                    (d.type == DealType.bought
                            ? AppColors.accent
                            : AppColors.whatsApp)
                        .withValues(alpha: 0.14),
                child: Icon(
                  d.type == DealType.bought
                      ? Icons.sell_outlined
                      : Icons.key_outlined,
                  color: d.type == DealType.bought
                      ? AppColors.accent
                      : AppColors.whatsApp,
                ),
              ),
              title: Text(d.item),
              subtitle: Text(
                [
                  d.type.label,
                  formatDate(context, d.date),
                  ?d.location,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
      ],
    );
  }
}
