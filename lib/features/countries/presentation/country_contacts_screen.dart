import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_view.dart';
import '../../broadcast/presentation/broadcast_compose_screen.dart';
import '../../broadcast/presentation/broadcast_providers.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../../contacts/domain/app_contact.dart';
import '../../contacts/presentation/contact_tile.dart';
import '../../contacts/presentation/contacts_providers.dart';

class CountryContactsScreen extends ConsumerWidget {
  const CountryContactsScreen({super.key, required this.countryKey});

  final String countryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(countryGroupProvider(countryKey));
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const StateView(
          icon: Icons.search_off_rounded,
          title: 'No contacts here',
          message: 'This country no longer has any contacts.',
        ),
      );
    }
    final theme = Theme.of(context);
    final country = group.country;
    final padding = contentPadding(context);

    final selecting = ref.watch(selectionProvider.select((s) => s.active));

    return PopScope(
      // Back leaves selection mode first.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(selectionProvider.notifier).exit();
      },
      child: Scaffold(
        appBar: _CountryAppBar(countryKey: countryKey),
        bottomNavigationBar: selecting
            ? _SelectionBar(countryKey: countryKey)
            : null,
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(contactsControllerProvider.notifier).refresh(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: padding.copyWith(top: 8),
                sliver: SliverToBoxAdapter(
                  child: _CountryBanner(
                    group: group,
                    total: ref.watch(
                      directoryProvider.select((d) => d?.totalContacts ?? 0),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: padding.copyWith(top: 16, bottom: 4),
                sliver: SliverToBoxAdapter(
                  child: SearchField(
                    hint: 'Search ${country?.name ?? 'Unknown'} contacts',
                    onChanged: ref
                        .read(searchQueryProvider(countryKey).notifier)
                        .update,
                  ),
                ),
              ),
              if (group.isUnknown)
                SliverPadding(
                  padding: padding.copyWith(top: 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'These numbers have no country code, or aren’t valid. '
                      'Choosing a default region in Settings can classify '
                      'local numbers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              _CountryContactList(countryKey: countryKey, padding: padding),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _CountryAppBar({required this.countryKey});

  final String countryKey;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final controller = ref.read(selectionProvider.notifier);
    if (!selection.active) {
      return AppBar(
        actions: [
          TextButton.icon(
            key: const Key('start-select'),
            onPressed: controller.start,
            icon: const Icon(Icons.checklist_rounded, size: 20),
            label: const Text('Select'),
          ),
          const SizedBox(width: 8),
        ],
      );
    }
    final visible = ref.watch(countryContactsProvider(countryKey));
    final allSelected =
        visible.isNotEmpty &&
        selection.ids.containsAll(visible.map((c) => c.id));
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close_rounded),
        onPressed: controller.exit,
      ),
      title: Text('${selection.count} selected'),
      actions: [
        TextButton(
          key: const Key('select-all'),
          onPressed: () => controller.toggleAll(visible.map((c) => c.id)),
          child: Text(allSelected ? 'Deselect all' : 'Select all'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.countryKey});

  final String countryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(selectionProvider.select((s) => s.count));
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0
                      ? 'Tap contacts to select them'
                      : '$count ${count == 1 ? 'contact' : 'contacts'} selected',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                key: const Key('message-selected'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: count == 0
                    ? null
                    : () {
                        ref
                            .read(broadcastDraftProvider.notifier)
                            .begin(
                              ref.read(selectionProvider).ids,
                              countryKey: countryKey,
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BroadcastComposeScreen(),
                          ),
                        );
                      },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isolated so typing in the search box only rebuilds the list.
class _CountryContactList extends ConsumerWidget {
  const _CountryContactList({required this.countryKey, required this.padding});

  final String countryKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(countryContactsProvider(countryKey));
    if (contacts.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: StateView(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: 'Try a different name or number.',
        ),
      );
    }
    return SliverPadding(
      padding: padding.copyWith(top: 16, bottom: 32),
      sliver: SliverList.builder(
        itemCount: contacts.length,
        itemBuilder: (context, i) => GroupedListItem(
          key: ValueKey(contacts[i].id),
          index: i,
          count: contacts.length,
          child: ContactTile(
            contact: contacts[i],
            countryKey: countryKey,
            selectable: true,
          ),
        ),
      ),
    );
  }
}

/// Gradient header with a large flag and key stats.
class _CountryBanner extends StatelessWidget {
  const _CountryBanner({required this.group, required this.total});

  final CountryGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = group.country;
    final numbers = group.contacts.fold<int>(
      0,
      (sum, c) => sum + c.phonesFor(group.key).length,
    );
    final share = total == 0 ? 0 : (group.count / total * 100).round();
    final muted = Colors.white.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 6),
        gradient: AppColors.hero(theme.brightness),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: country == null
                    ? const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 34,
                      )
                    : Text(
                        country.flag,
                        style: const TextStyle(fontSize: 40, height: 1.1),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country?.name ?? 'Unknown country',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      country == null
                          ? 'Numbers that couldn’t be matched to a country'
                          : '${country.formattedDialCode}  ·  '
                                '${country.isoCode}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _BannerStat(
                value: '${group.count}',
                label: group.count == 1 ? 'contact' : 'contacts',
              ),
              _BannerStat(
                value: '$numbers',
                label: numbers == 1 ? 'number' : 'numbers',
              ),
              _BannerStat(value: '$share%', label: 'of all contacts'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
