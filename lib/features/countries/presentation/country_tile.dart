import 'package:flutter/material.dart';

import '../../../core/widgets/flag_badge.dart';
import '../../contacts/domain/app_contact.dart';
import 'country_contacts_screen.dart';

/// Country row with flag, dialing code, count and share-of-total bar.
class CountryTile extends StatelessWidget {
  const CountryTile({super.key, required this.group, required this.total});

  final CountryGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final country = group.country;
    final share = total == 0 ? 0.0 : group.count / total;
    final percent = (share * 100);
    final percentLabel = percent > 0 && percent < 1
        ? '<1%'
        : '${percent.round()}%';

    return Semantics(
      button: true,
      label:
          '${country?.name ?? 'Unknown'}, ${group.count} contacts, $percentLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CountryContactsScreen(countryKey: group.key),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              FlagBadge(country: country, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            country?.name ?? 'Unknown',
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            country?.formattedDialCode ?? 'Unclassified',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 5,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: group.isUnknown
                            ? scheme.outline
                            : scheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${group.count}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
