import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'country_time_zones.dart';

/// The current wall-clock time in a country.
class CountryLocalTime {
  const CountryLocalTime({
    required this.primary,
    required this.earliest,
    required this.latest,
  });

  /// Calls and messages are discouraged from 21:00 to 07:59.
  static const quietFromHour = 21;
  static const quietUntilHour = 8;

  /// In the country's most populous time zone.
  final DateTime primary;

  /// Earliest and latest wall-clock time across all of the country's zones;
  /// equal to [primary] for single-zone countries.
  final DateTime earliest;
  final DateTime latest;

  bool get spansZones => earliest != latest;

  bool get isLateNight =>
      primary.hour >= quietFromHour || primary.hour < quietUntilHour;
}

bool _initialized = false;

/// Local time in [isoCode] at the instant [now], or null for an unknown
/// country. Uses the IANA time zone database bundled with the app, so it
/// follows daylight saving changes and works offline.
CountryLocalTime? localTimeIn(String? isoCode, DateTime now) {
  final zones = countryTimeZones[isoCode];
  if (zones == null) return null;
  if (!_initialized) {
    tzdata.initializeTimeZones();
    _initialized = true;
  }
  final utc = now.toUtc();
  final walls = [
    for (final name in zones)
      if (tz.timeZoneDatabase.locations[name] case final location?)
        _wallClock(tz.TZDateTime.from(utc, location)),
  ];
  if (walls.isEmpty) return null;
  final sorted = [...walls]..sort();
  return CountryLocalTime(
    primary: walls.first,
    earliest: sorted.first,
    latest: sorted.last,
  );
}

/// The zone's local date and time as a plain (offset-free) DateTime.
DateTime _wallClock(tz.TZDateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);
