import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/state_view.dart';
import '../data/crm_database.dart';
import 'activity_form_screen.dart';
import 'activity_widgets.dart';
import 'crm_providers.dart';

/// The Activities tab, grouped into Overdue, Today, Upcoming, No date and
/// Done.
class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  ActivityType? _type;
  var _showDone = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activitiesProvider(null));
    final all = async.value ?? const <Activity>[];
    final padding = contentPadding(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final visible = [
      for (final a in all)
        if (_type == null || a.type == _type) a,
    ];
    final open = visible.where((a) => a.completedAt == null);
    final sections = <(String, List<Activity>)>[
      (
        'Overdue',
        [
          for (final a in open)
            if (a.dueAt != null && a.dueAt!.isBefore(today)) a,
        ],
      ),
      (
        'Today',
        [
          for (final a in open)
            if (a.dueAt != null &&
                !a.dueAt!.isBefore(today) &&
                a.dueAt!.isBefore(tomorrow))
              a,
        ],
      ),
      (
        'Upcoming',
        [
          for (final a in open)
            if (a.dueAt != null && !a.dueAt!.isBefore(tomorrow)) a,
        ],
      ),
      (
        'No date',
        [
          for (final a in open)
            if (a.dueAt == null) a,
        ],
      ),
      if (_showDone)
        (
          'Done',
          [
            for (final a in visible)
              if (a.completedAt != null) a,
          ],
        ),
    ];
    final doneCount = visible.where((a) => a.completedAt != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        actions: [
          TextButton(
            key: const Key('show-done'),
            onPressed: () => setState(() => _showDone = !_showDone),
            child: Text(_showDone ? 'Hide done' : 'Show done ($doneCount)'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-activity'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ActivityFormScreen()),
        ),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New activity'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding.copyWith(top: 4, bottom: 4),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      key: const ValueKey('activity-filter-all'),
                      label: const Text('All'),
                      selected: _type == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    for (final t in ActivityType.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: ValueKey('activity-filter-${t.name}'),
                        avatar: Icon(t.icon, size: 16, color: t.color),
                        label: Text(t.label),
                        selected: _type == t,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _type = _type == t ? null : t),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (async.isLoading && all.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sections.every((s) => s.$2.isEmpty))
            SliverFillRemaining(
              hasScrollBody: false,
              child: all.isEmpty
                  ? const StateView(
                      icon: Icons.event_note_outlined,
                      title: 'No activities yet',
                      message:
                          'Plan calls, meetings, tasks, emails and lunches '
                          'with your leads, clients and contacts.',
                    )
                  : StateView(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'All clear',
                      message: doneCount > 0 && !_showDone
                          ? 'Nothing open here. Tap “Show done” to see '
                                'finished activities.'
                          : 'No activities match this filter.',
                    ),
            )
          else
            for (final (title, items) in sections)
              if (items.isNotEmpty) ...[
                SliverPadding(
                  padding: padding,
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(title, trailing: '${items.length}'),
                  ),
                ),
                SliverPadding(
                  padding: padding,
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => GroupedListItem(
                      key: ValueKey(items[i].id),
                      index: i,
                      count: items.length,
                      child: ActivityTile(activity: items[i]),
                    ),
                  ),
                ),
              ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

/// Activities with one lead or client, for their detail page.
class PartyActivities extends ConsumerWidget {
  const PartyActivities({super.key, required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(activitiesProvider(party.id)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Activities',
          trailing: '${items.length}',
          action: TextButton.icon(
            key: const Key('add-party-activity'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ActivityFormScreen(
                  initialWho: (
                    partyId: party.id,
                    contactId: null,
                    name: party.name,
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No calls, meetings or tasks yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final (i, a) in items.indexed)
          GroupedListItem(
            key: ValueKey(a.id),
            index: i,
            count: items.length,
            child: ActivityTile(activity: a, showWho: false),
          ),
      ],
    );
  }
}
