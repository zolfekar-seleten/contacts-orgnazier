import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/search_field.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../data/crm_database.dart';
import '../domain/party_phone.dart';
import 'crm_providers.dart';
import 'crm_widgets.dart';

/// Who an activity is with: a lead or client, or a phone contact.
typedef ActivityWho = ({String? partyId, String? contactId, String name});

enum _WhoTab { leads, clients, contacts }

/// Lets the user pick a lead, client or contact. Returns null if dismissed.
Future<ActivityWho?> showWhoPicker(BuildContext context) =>
    showModalBottomSheet<ActivityWho>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _WhoPicker(),
    );

class _WhoPicker extends ConsumerStatefulWidget {
  const _WhoPicker();

  @override
  ConsumerState<_WhoPicker> createState() => _WhoPickerState();
}

class _WhoPickerState extends ConsumerState<_WhoPicker> {
  var _tab = _WhoTab.leads;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final List<Widget> rows;
    switch (_tab) {
      case _WhoTab.leads || _WhoTab.clients:
        final kind = _tab == _WhoTab.leads ? PartyKind.lead : PartyKind.client;
        final parties = (ref.watch(partiesProvider(kind)).value ?? const [])
            .where((p) => matchesPartyQuery(p, q))
            .toList();
        rows = [
          for (final p in parties)
            ListTile(
              key: ValueKey('who-${p.id}'),
              leading: PartyAvatar(party: p, size: 36),
              title: Text(p.name),
              subtitle: p.phoneDisplay == null ? null : Text(p.phoneDisplay!),
              onTap: () => Navigator.pop(context, (
                partyId: p.id,
                contactId: null,
                name: p.name,
              )),
            ),
        ];
      case _WhoTab.contacts:
        final directory = ref.watch(directoryProvider);
        final contacts = (directory?.contacts ?? const [])
            .where((c) => q.isEmpty || c.displayName.toLowerCase().contains(q))
            .take(200)
            .toList();
        rows = [
          if (directory == null)
            const ListTile(
              title: Text('Contacts aren’t available'),
              subtitle: Text('Allow contacts access on the Contacts tab.'),
            ),
          for (final c in contacts)
            ListTile(
              key: ValueKey('who-contact-${c.id}'),
              leading: ContactAvatar(contact: c, size: 36),
              title: Text(c.displayName),
              subtitle: Text(c.primaryPhone()?.display ?? ''),
              onTap: () => Navigator.pop(context, (
                partyId: null,
                contactId: c.id,
                name: c.displayName,
              )),
            ),
        ];
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('With who?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<_WhoTab>(
                  segments: const [
                    ButtonSegment(value: _WhoTab.leads, label: Text('Leads')),
                    ButtonSegment(
                      value: _WhoTab.clients,
                      label: Text('Clients'),
                    ),
                    ButtonSegment(
                      value: _WhoTab.contacts,
                      label: Text('Contacts'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                const SizedBox(height: 10),
                SearchField(
                  hint: 'Search',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Nobody found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    controller: scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: rows,
                  ),
          ),
        ],
      ),
    );
  }
}
