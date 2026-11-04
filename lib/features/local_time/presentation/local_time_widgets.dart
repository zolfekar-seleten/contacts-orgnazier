import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../communication/domain/communication_kind.dart';
import '../../countries/domain/country.dart';
import '../domain/local_time.dart';

/// `9:41 PM`, or `21:41` when the device uses 24-hour time.
String formatClock(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// `9:41 PM`, or a range like `8:41 – 11:41 PM` across several time zones.
String formatLocalTime(BuildContext context, CountryLocalTime time) =>
    time.spansZones
    ? '${formatClock(context, time.earliest)} – '
          '${formatClock(context, time.latest)}'
    : formatClock(context, time.primary);

Color lateNightColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFC870)
    : const Color(0xFF8A5300);

/// "🕘 9:41 PM local time", refreshed every minute; amber with a moon at
/// night. Renders nothing for an unknown country.
class LocalTimeLabel extends ConsumerWidget {
  const LocalTimeLabel({
    super.key,
    required this.isoCode,
    this.color,
    this.suffix = ' local time',
  });

  final String? isoCode;

  /// Daytime text colour; defaults to the muted body colour.
  final Color? color;
  final String suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteTickProvider);
    final time = localTimeIn(isoCode, now);
    if (time == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final late = time.isLateNight;
    final c = late
        ? lateNightColor(context)
        : color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          late ? Icons.bedtime_outlined : Icons.schedule_rounded,
          size: 14,
          color: c,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${formatLocalTime(context, time)}$suffix'
            '${late ? ' · late night' : ''}',
            key: ValueKey('local-time-$isoCode'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

/// Before calling or messaging someone where it's late at night, asks
/// whether to go ahead. Returns true to continue.
Future<bool> confirmLateNight(
  BuildContext context,
  WidgetRef ref, {
  required String? isoCode,
  required String name,
  required CommunicationKind kind,
}) async {
  final time = localTimeIn(isoCode, ref.read(clockProvider)());
  if (time == null || !time.isLateNight) return true;
  final country = Country.fromIso(isoCode)?.name ?? 'their country';
  final action = kind == CommunicationKind.call ? 'call' : 'message';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.bedtime_outlined, color: lateNightColor(context)),
      title: Text('It’s ${formatClock(context, time.primary)} in $country'),
      content: Text(
        'It may be a bad time to $action $name.'
        '${time.spansZones ? ' Local time there is ${formatLocalTime(context, time)}, depending on the region.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('late-night-continue'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            kind == CommunicationKind.call ? 'Call anyway' : 'Message anyway',
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
