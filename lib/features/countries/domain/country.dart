import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'country_names.dart';

/// A country (or numbering region) known to libphonenumber metadata.
class Country {
  const Country._({
    required this.isoCode,
    required this.name,
    required this.dialCode,
  });

  /// ISO 3166-1 alpha-2 code, e.g. `GB`.
  final String isoCode;

  /// English display name, e.g. `United Kingdom`.
  final String name;

  /// International dialing code without the `+`, e.g. `44`.
  final String dialCode;

  /// Emoji flag built from the regional indicator symbols of [isoCode].
  String get flag => String.fromCharCodes(
    isoCode.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
  );

  String get formattedDialCode => '+$dialCode';

  static final Map<String, Country> _byIso = {
    for (final iso in IsoCode.values)
      iso.name: Country._(
        isoCode: iso.name,
        name: countryNames[iso.name] ?? iso.name,
        dialCode: PhoneNumber(isoCode: iso, nsn: '').countryCode,
      ),
  };

  /// All supported regions, sorted by name.
  static final List<Country> all = _byIso.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  /// Looks up a country by ISO code (case-insensitive).
  static Country? fromIso(String? isoCode) =>
      isoCode == null ? null : _byIso[isoCode.toUpperCase()];

  @override
  bool operator ==(Object other) =>
      other is Country && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;

  @override
  String toString() => 'Country($isoCode)';
}
