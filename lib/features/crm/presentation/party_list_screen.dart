import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_view.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../../import/presentation/import_screen.dart';
import '../data/crm_database.dart';
import '../domain/party_phone.dart';
import 'crm_providers.dart';
import 'crm_widgets.dart';
import 'party_detail_screen.dart';
import 'party_form_screen.dart';
import 'sample_data_controls.dart';
import 'status_manager_screen.dart';

/// The Leads or Clients tab.
class PartyListScreen extends ConsumerWidget {
  const PartyListScreen({super.key, required this.kind});

  final PartyKind kind;

  bool get _leads => kind == PartyKind.lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visiblePartiesProvider(kind));
    final total = ref.watch(partiesProvider(kind)).value?.length ?? 0;
    final padding = contentPadding(context);
    final noun = _leads ? 'lead' : 'client';

    return Scaffold(
      appBar: AppBar(
        title: Text(_leads ? 'Leads' : 'Clients'),
        actions: [
          IconButton(
            key: Key('import-$noun'),
            tooltip: 'Import from Excel',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ImportScreen(kind: kind)),
            ),
          ),
          if (_leads)
            IconButton(
              key: const Key('manage-statuses'),
              tooltip: 'Statuses',
              icon: const Icon(Icons.label_outline_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StatusManagerScreen(),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: Key('add-$noun'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PartyFormScreen(kind: kind)),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_leads ? 'Add lead' : 'Add client'),
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: padding.copyWith(top: 4, bottom: 8),
            sliver: SliverToBoxAdapter(
              child: SearchField(
                hint: 'Search name, mobile or source',
                onChanged: ref
                    .read(searchQueryProvider(partySearchScope(kind)).notifier)
                    .update,
              ),
            ),
          ),
          if (_leads)
            SliverPadding(
              padding: padding.copyWith(top: 4, bottom: 4),
              sliver: const SliverToBoxAdapter(child: _StatusFilter()),
            ),
          ...switch (visible) {
            AsyncData(:final value) when value.isEmpty => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: total == 0
                    ? StateView(
                        icon: _leads
                            ? Icons.trending_up_rounded
                            : Icons.handshake_outlined,
                        title: _leads ? 'No leads yet' : 'No clients yet',
                        message: _leads
                            ? 'Add the people you are following up with. '
                                  'When one buys or rents, convert them to a '
                                  'client.'
                            : 'Convert a lead, or add a client directly, '
                                  'to keep track of what they bought or '
                                  'rented.',
                        secondaryLabel: 'Try with sample data',
                        onSecondary: () => addSampleData(context, ref),
                      )
                    : const StateView(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        message: 'Try a different name, number or status.',
                      ),
              ),
            ],
            AsyncData(:final value) => [
              SliverPadding(
                padding: padding.copyWith(top: 8, bottom: 96),
                sliver: SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, i) => GroupedListItem(
                    key: ValueKey(value[i].id),
                    index: i,
                    count: value.length,
                    child: _PartyTile(party: value[i]),
                  ),
                ),
              ),
            ],
            AsyncError() => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  message: 'Your data couldn’t be loaded.',
                ),
              ),
            ],
            _ => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ],
      ),
    );
  }
}

/// All · Cold 4 · Hot 2 … chips.
class _StatusFilter extends ConsumerWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(leadStatusesProvider).value ?? const [];
    final leads = ref.watch(partiesProvider(PartyKind.lead)).value ?? const [];
    final selected = ref.watch(leadStatusFilterProvider);
    final filter = ref.read(leadStatusFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('status-all'),
            label: Text('All ${leads.length}'),
            selected: selected == null,
            showCheckmark: false,
            onSelected: (_) => filter.set(null),
          ),
          for (final s in statuses) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey('status-${s.name}'),
              avatar: CircleAvatar(backgroundColor: Color(s.color), radius: 5),
              label: Text(
                '${s.name} ${leads.where((l) => l.statusId == s.id).length}',
              ),
              selected: selected == s.id,
              showCheckmark: false,
              onSelected: (_) => filter.set(selected == s.id ? null : s.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartyTile extends ConsumerWidget {
  const _PartyTile({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = party.kind == PartyKind.lead
        ? ref
              .watch(leadStatusesProvider)
              .value
              ?.where((s) => s.id == party.statusId)
              .firstOrNull
        : null;
    final flag = party.residenceCountry?.flag ?? party.nationalityCountry?.flag;
    final details = [
      ?party.phoneDisplay,
      if (party.source != null) [party.source, ?party.subSource].join(' · '),
    ];

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PartyDetailScreen(partyId: party.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            PartyAvatar(party: party),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final line in details)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (status != null)
              StatusPill(status: status)
            else if (flag != null)
              Text(flag, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
