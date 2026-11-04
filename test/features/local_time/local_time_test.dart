import 'package:country_contacts/features/local_time/domain/country_time_zones.dart';
import 'package:country_contacts/features/local_time/domain/local_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('follows daylight saving time', () {
    final summer = localTimeIn('GB', DateTime.utc(2026, 6, 15, 12))!;
    final winter = localTimeIn('GB', DateTime.utc(2026, 1, 15, 12))!;
    expect(summer.primary, DateTime(2026, 6, 15, 13));
    expect(winter.primary, DateTime(2026, 1, 15, 12));
    expect(summer.spansZones, isFalse);
  });

  test('countries without daylight saving and with half-hour offsets', () {
    expect(
      localTimeIn('AE', DateTime.utc(2026, 6, 15, 12))!.primary,
      DateTime(2026, 6, 15, 16),
    );
    expect(
      localTimeIn('IN', DateTime.utc(2026, 6, 15, 12))!.primary,
      DateTime(2026, 6, 15, 17, 30),
    );
  });

  test('late night is 21:00 to 07:59 in the main zone', () {
    bool lateAt(int hour, int minute) => localTimeIn(
      'AE',
      DateTime.utc(2026, 6, 15, hour - 4, minute),
    )!.isLateNight;
    expect(lateAt(20, 59), isFalse);
    expect(lateAt(21, 0), isTrue);
    expect(lateAt(7, 59), isTrue);
    expect(lateAt(8, 0), isFalse);
  });

  test('multi-zone countries report a range and use the main zone', () {
    final us = localTimeIn('US', DateTime.utc(2026, 1, 15, 17))!;
    expect(us.primary, DateTime(2026, 1, 15, 12)); // New York
    expect(us.earliest, DateTime(2026, 1, 15, 7)); // Honolulu
    expect(us.latest, DateTime(2026, 1, 15, 12));
    expect(us.spansZones, isTrue);

    final ru = localTimeIn('RU', DateTime.utc(2026, 1, 15, 9))!;
    expect(ru.primary, DateTime(2026, 1, 15, 12)); // Moscow
    expect(ru.latest, DateTime(2026, 1, 15, 21)); // Kamchatka
  });

  test('unknown countries have no local time', () {
    expect(localTimeIn('ZZ', DateTime.utc(2026)), isNull);
    expect(localTimeIn(null, DateTime.utc(2026)), isNull);
  });

  test('every mapped country resolves', () {
    final now = DateTime.utc(2026, 6, 15, 12);
    for (final iso in countryTimeZones.keys) {
      expect(localTimeIn(iso, now), isNotNull, reason: iso);
    }
  });
}
