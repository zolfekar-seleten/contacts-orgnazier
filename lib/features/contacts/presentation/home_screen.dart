import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/donut_chart.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_view.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../../countries/presentation/country_contacts_screen.dart';
import '../../countries/presentation/country_search_screen.dart';
import '../../countries/presentation/country_tile.dart';
import '../../duplicates/presentation/duplicates_providers.dart';
import '../../duplicates/presentation/duplicates_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/app_contact.dart';
import '../domain/contact_directory.dart';
import 'contact_tile.dart';
import 'contacts_providers.dart';
import 'permission_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static void openSettings(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(contactsViewProvider);
    // The content state brings its own collapsing large header.
    final hasContent = switch (view.value) {
      ContactsReady(:final directory) => !directory.isEmpty,
      _ => false,
    };
    return Scaffold(
      appBar: hasContent
          ? null
          : AppBar(
              title: const Text('Contacts Organizer'),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => openSettings(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: view.when(
          skipLoadingOnReload: true,
          loading: () => const _LoadingView(key: ValueKey('loading')),
          error: (error, _) => StateView(
            key: const ValueKey('error'),
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            message: 'Your contacts couldn’t be loaded. Please try again.',
            primaryLabel: 'Retry',
            onPrimary: () => ref.invalidate(contactsControllerProvider),
          ),
          data: (data) => switch (data) {
            NeedsPermission(:final status) => PermissionView(
              key: ValueKey(status),
              status: status,
            ),
            ContactsReady(:final directory) when directory.isEmpty => StateView(
              key: const ValueKey('empty'),
              icon: Icons.person_search_rounded,
              title: 'No contacts with phone numbers',
              message:
                  'Contacts you add to your phone will appear here, grouped '
                  'by country.',
              primaryLabel: 'Refresh',
              onPrimary: () =>
                  ref.read(contactsControllerProvider.notifier).refresh(),
            ),
            ContactsReady(:final directory) => _HomeContent(
              key: const ValueKey('content'),
              directory: directory,
            ),
          },
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.hero(theme.brightness),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text('Organising your contacts…', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Matching numbers to countries on your device',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({super.key, required this.directory});

  final ContactDirectory directory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final padding = contentPadding(context);
    final isSearching = ref.watch(
      globalSearchProvider.select((r) => r != null),
    );
    return RefreshIndicator(
      edgeOffset: 120,
      onRefresh: () => ref.read(contactsControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // The app-wide title style would also shrink the expanded large
          // title, so this header uses the Material defaults for both sizes.
          Theme(
            data: theme.copyWith(
              appBarTheme: AppBarTheme(
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false,
              ),
            ),
            child: SliverAppBar.large(
              title: const Text('Contacts Organizer'),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => HomeScreen.openSettings(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          SliverPadding(
            padding: padding.copyWith(top: 0, bottom: 8),
            sliver: SliverToBoxAdapter(
              child: SearchField(
                hint: 'Search name, number or country',
                onChanged: ref
                    .read(searchQueryProvider(globalSearchScope).notifier)
                    .update,
              ),
            ),
          ),
          if (isSearching)
            _SearchResults(padding: padding)
          else ...[
            SliverPadding(
              padding: padding.copyWith(top: 12),
              sliver: SliverToBoxAdapter(
                child: _OverviewCard(directory: directory),
              ),
            ),
            SliverPadding(
              padding: padding.copyWith(top: 12),
              sliver: const SliverToBoxAdapter(child: _DuplicatesCard()),
            ),
            if (directory.countries.length > 1) ...[
              SliverPadding(
                padding: padding,
                sliver: const SliverToBoxAdapter(
                  child: SectionHeader('Top countries'),
                ),
              ),
              SliverToBoxAdapter(
                child: _TopCountries(directory: directory, padding: padding),
              ),
            ],
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  'All countries',
                  trailing: '${directory.countries.length}',
                  action: TextButton.icon(
                    key: const Key('find-country'),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Find country'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CountrySearchScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: padding,
              sliver: SliverList.builder(
                itemCount: directory.countries.length,
                itemBuilder: (context, i) => GroupedListItem(
                  key: ValueKey(directory.countries[i].key),
                  index: i,
                  count: directory.countries.length,
                  child: CountryTile(
                    group: directory.countries[i],
                    total: directory.totalContacts,
                  ),
                ),
              ),
            ),
            if (directory.unknown.count > 0) ...[
              SliverPadding(
                padding: padding,
                sliver: const SliverToBoxAdapter(
                  child: SectionHeader('Uncategorised'),
                ),
              ),
              SliverPadding(
                padding: padding,
                sliver: SliverToBoxAdapter(
                  child: GroupedListItem(
                    index: 0,
                    count: 1,
                    child: CountryTile(
                      group: directory.unknown,
                      total: directory.totalContacts,
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ],
      ),
    );
  }
}

/// Count of duplicated contacts; opens [DuplicatesScreen].
class _DuplicatesCard extends ConsumerWidget {
  const _DuplicatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(duplicatesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = report.contactCount;
    final groups = report.groups.length;
    final accent = count == 0 ? scheme.secondary : scheme.error;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('open-duplicates'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DuplicatesScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  count == 0
                      ? Icons.verified_rounded
                      : Icons.content_copy_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duplicated contacts',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'No duplicates found'
                          : 'In $groups ${groups == 1 ? 'group' : 'groups'} '
                                '· same number or name',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                key: const Key('duplicates-count'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _percent(int count, int total) {
  if (total == 0) return '0%';
  final p = count / total * 100;
  return p > 0 && p < 1 ? '<1%' : '${p.round()}%';
}

/// Hero card: totals, a donut of the largest countries and a legend.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.directory});

  final ContactDirectory directory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = directory.countries.take(AppColors.chart.length).toList();
    final restSum = directory.countries
        .skip(top.length)
        .fold<int>(directory.unknown.count, (s, g) => s + g.count);
    final muted = Colors.white.withValues(alpha: 0.7);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 6),
        gradient: AppColors.hero(theme.brightness),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Soft decorative glows.
          Positioned(
            right: -60,
            top: -70,
            child: _Glow(size: 200, color: const Color(0xFF6C8CFF)),
          ),
          Positioned(
            left: -50,
            bottom: -80,
            child: _Glow(size: 180, color: const Color(0xFF34D3A6)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total contacts',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${directory.totalContacts}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 22,
                            runSpacing: 10,
                            children: [
                              _Stat(
                                label: 'Numbers',
                                value: '${directory.totalNumbers}',
                              ),
                              _Stat(
                                label: 'Uncategorised',
                                value: '${directory.unknown.count}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DonutChart(
                      size: 112,
                      thickness: 11,
                      colors: [
                        ...AppColors.chart.take(top.length),
                        Colors.white.withValues(alpha: 0.22),
                      ],
                      values: [
                        for (final g in top) g.count.toDouble(),
                        restSum.toDouble(),
                      ],
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${directory.countries.length}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'countries',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < top.length; i++)
                        _LegendPill(
                          color: AppColors.chart[i],
                          label:
                              '${top[i].country!.flag} '
                              '${_percent(top[i].count, directory.totalContacts)}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal carousel of the largest countries for one-tap access.
class _TopCountries extends StatelessWidget {
  const _TopCountries({required this.directory, required this.padding});

  final ContactDirectory directory;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final top = directory.countries.take(10).toList();
    // Grow with the user's text size so labels never clip.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 108 + 36 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(padding.left, 2, padding.right, 10),
        itemCount: top.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _TopCountryCard(
          key: ValueKey('top-${top[i].key}'),
          group: top[i],
          total: directory.totalContacts,
        ),
      ),
    );
  }
}

class _TopCountryCard extends StatelessWidget {
  const _TopCountryCard({super.key, required this.group, required this.total});

  final CountryGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final country = group.country!;
    return Container(
      width: 124,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppColors.softShadow(theme.brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CountryContactsScreen(countryKey: group.key),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 30, height: 1.1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _percent(group.count, total),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  country.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  group.count == 1 ? '1 contact' : '${group.count} contacts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(globalSearchProvider);
    final total = ref.watch(
      directoryProvider.select((d) => d?.totalContacts ?? 0),
    );
    if (results == null) return const SliverToBoxAdapter();
    final (:countries, :contacts) = results;
    if (countries.isEmpty && contacts.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: StateView(
          icon: Icons.search_off_rounded,
          title: 'No results',
          message: 'Try a name, a number, a country or a code like +44.',
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (countries.isNotEmpty) ...[
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Countries',
                trailing: '${countries.length}',
              ),
            ),
          ),
          SliverPadding(
            padding: padding,
            sliver: SliverList.builder(
              itemCount: countries.length,
              itemBuilder: (context, i) => GroupedListItem(
                key: ValueKey(countries[i].key),
                index: i,
                count: countries.length,
                child: CountryTile(group: countries[i], total: total),
              ),
            ),
          ),
        ],
        if (contacts.isNotEmpty) ...[
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: SectionHeader('Contacts', trailing: '${contacts.length}'),
            ),
          ),
          SliverPadding(
            padding: padding.copyWith(bottom: 40),
            sliver: SliverList.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) => GroupedListItem(
                key: ValueKey(contacts[i].id),
                index: i,
                count: contacts.length,
                child: ContactTile(contact: contacts[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
