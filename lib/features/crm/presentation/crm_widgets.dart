import 'package:flutter/material.dart';

import '../../../core/widgets/contact_avatar.dart';
import '../data/crm_database.dart';
import '../domain/party_phone.dart';

class PartyAvatar extends StatelessWidget {
  const PartyAvatar({super.key, required this.party, this.size = 44});

  final Party party;
  final double size;

  @override
  Widget build(BuildContext context) =>
      InitialsAvatar(seed: party.id, initials: party.initials, size: size);
}

/// Coloured status label, e.g. "Hot".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.onTap});

  final LeadStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(status.color);
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Color.lerp(color, theme.colorScheme.onSurface, 0.35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Colours offered for statuses.
const statusPalette = [
  0xFF3D8BF5,
  0xFFF0544F,
  0xFFFFA000,
  0xFF22B07D,
  0xFF8E5CF7,
  0xFFEC5FA6,
  0xFF00ACC1,
  0xFF6D7A8C,
];

/// "12 Nov 2026" in the device's locale.
String formatDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);
