import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flag_badge.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/state_view.dart';
import '../../contacts/presentation/contact_tile.dart';
import '../domain/duplicate_finder.dart';
import 'duplicates_providers.dart';

class DuplicatesScreen extends ConsumerWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(duplicatesProvider);
    final padding = contentPadding(context);
    final theme = Theme.of(context);

    if (report.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicates')),
        body: const StateView(
          icon: Icons.verified_rounded,
          title: 'No duplicates found',
          message:
              'No two contacts share a phone number or have the same name.',
        ),
      );
    }

    final byPhone = report.byPhone.toList();
    final byName = report.byName.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicates')),
      body: ListView(
        padding: padding.copyWith(top: 8, bottom: 40),
        children: [
          _Summary(report: report),
          if (byPhone.isNotEmpty) ...[
            SectionHeader('Same phone number', trailing: '${byPhone.length}'),
            for (final g in byPhone) _GroupCard(group: g),
          ],
          if (byName.isNotEmpty) ...[
            SectionHeader('Same name', trailing: '${byName.length}'),
            for (final g in byName) _GroupCard(group: g),
          ],
          const SizedBox(height: 12),
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
                  'Open a contact and tap Edit to fix it in your Contacts '
                  'app. Contacts Organizer never merges or deletes contacts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report});

  final DuplicateReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = Colors.white.withValues(alpha: 0.7);
    final groups = report.groups.length;
    return Container(
      key: const Key('duplicates-summary'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 6),
        gradient: AppColors.hero(theme.brightness),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicated contacts',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.contactCount}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'in $groups ${groups == 1 ? 'group' : 'groups'}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.content_copy_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final samePhone = group.reason == DuplicateReason.samePhone;
    return Container(
      key: ValueKey('dup-${group.reason.name}-${group.key}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (samePhone)
                  FlagBadge(country: group.phone!.country, size: 36)
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      size: 20,
                      color: scheme.secondary,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        samePhone
                            ? 'Saved on ${group.contacts.length} contacts'
                            : '${group.contacts.length} contacts with this name',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '×${group.contacts.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final contact in group.contacts) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            ContactTile(contact: contact),
          ],
        ],
      ),
    );
  }
}
