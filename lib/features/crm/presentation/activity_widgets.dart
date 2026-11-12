import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../local_time/presentation/local_time_widgets.dart';
import '../data/crm_database.dart';
import 'activity_form_screen.dart';
import 'crm_providers.dart';

extension ActivityTypeStyle on ActivityType {
  IconData get icon => switch (this) {
    ActivityType.call => Icons.call_outlined,
    ActivityType.meeting => Icons.groups_outlined,
    ActivityType.task => Icons.task_alt_rounded,
    ActivityType.email => Icons.mail_outline_rounded,
    ActivityType.lunch => Icons.restaurant_outlined,
  };

  Color get color => switch (this) {
    ActivityType.call => const Color(0xFF3D6BF5),
    ActivityType.meeting => const Color(0xFF8E5CF7),
    ActivityType.task => const Color(0xFF22B07D),
    ActivityType.email => const Color(0xFF00ACC1),
    ActivityType.lunch => const Color(0xFFFF8A3D),
  };
}

extension ActivityPriorityStyle on ActivityPriority {
  Color get color => switch (this) {
    ActivityPriority.high => const Color(0xFFE5484D),
    ActivityPriority.medium => const Color(0xFFF5A524),
    ActivityPriority.low => const Color(0xFF8A94A6),
  };
}

/// Who an activity is with, for display.
String? activityWho(Activity a, Map<String, Party> parties) =>
    parties[a.partyId]?.name ?? a.contactName;

/// "Today 3:00 PM", "Tomorrow", "Fri 14 Nov 9:30 AM".
String formatDue(BuildContext context, DateTime due, DateTime now) {
  final day = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  final l = MaterialLocalizations.of(context);
  final date = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => l.formatMediumDate(due),
  };
  final hasTime = due.hour != 0 || due.minute != 0;
  return hasTime ? '$date ${formatClock(context, due)}' : date;
}

/// One activity: type icon, title, who and when, and a done checkbox.
class ActivityTile extends ConsumerWidget {
  const ActivityTile({super.key, required this.activity, this.showWho = true});

  final Activity activity;
  final bool showWho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = activity;
    final done = a.completedAt != null;
    final now = DateTime.now();
    final overdue = !done && a.dueAt != null && a.dueAt!.isBefore(now);
    final who = showWho ? activityWho(a, ref.watch(partiesByIdProvider)) : null;
    final images = ref.watch(attachmentCountsProvider).value?[a.id] ?? 0;
    final meta = [?who, if (a.dueAt != null) formatDue(context, a.dueAt!, now)];
    final preview = a.notePlain?.trim().split('\n').first;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityFormScreen(activity: a),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: a.type.color.withValues(alpha: done ? 0.06 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                a.type.icon,
                size: 20,
                color: done ? scheme.onSurfaceVariant : a.type.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!done) ...[
                        Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: a.priority.color,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            color: done ? scheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w600 : null,
                      ),
                    ),
                  if (preview != null && preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (images > 0) ...[
              Icon(
                Icons.image_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              Text(
                '$images',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            Checkbox(
              key: ValueKey('done-${a.id}'),
              value: done,
              shape: const CircleBorder(),
              onChanged: (v) => ref
                  .read(activityRepositoryProvider)
                  .setDone(a.id, done: v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
