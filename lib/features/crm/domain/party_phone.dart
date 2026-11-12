import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../contacts/domain/phone_classifier.dart';
import '../../countries/domain/country.dart';
import '../data/crm_database.dart';

/// Splits typed or pasted input into a calling code and national number.
/// `+971 50 123 4567` and `00971501234567` carry their own code; anything
/// else keeps [dialCode] and has a leading trunk `0` removed.
({String? dialCode, String? national}) splitPhone(
  String input, {
  String? dialCode,
}) {
  final normalized = normalizePhoneInput(input);
  if (normalized.isEmpty) return (dialCode: dialCode, national: null);
  final international = normalized.startsWith('+')
      ? normalized
      : normalized.startsWith('00')
      ? '+${normalized.substring(2)}'
      : null;
  if (international != null) {
    try {
      final p = PhoneNumber.parse(international);
      return (dialCode: p.countryCode, national: p.nsn);
    } on PhoneNumberException {
      return (dialCode: dialCode, national: normalized.replaceAll('+', ''));
    }
  }
  return (
    dialCode: dialCode,
    national: dialCode != null && normalized.startsWith('0')
        ? normalized.substring(1)
        : normalized,
  );
}

extension PartyDetails on Party {
  /// `+971501234567`, or null without a full number.
  String? get e164 => (dialCode == null || mobile == null || mobile!.isEmpty)
      ? null
      : '+$dialCode$mobile';

  PhoneNumber? get _parsed {
    final e164 = this.e164;
    if (e164 == null) return null;
    try {
      return PhoneNumber.parse(e164);
    } on PhoneNumberException {
      return null;
    }
  }

  /// `+971 50 123 4567`; falls back to the raw digits.
  String? get phoneDisplay {
    final p = _parsed;
    if (p != null) {
      return '+${p.countryCode} ${p.formatNsn(format: NsnFormat.international)}';
    }
    if (mobile == null || mobile!.isEmpty) return null;
    return dialCode == null ? mobile : '+$dialCode $mobile';
  }

  /// Region the number belongs to (for flags and local time).
  String? get phoneRegion => _parsed?.isoCode.name;

  Country? get nationalityCountry => Country.fromIso(nationality);
  Country? get residenceCountry => Country.fromIso(country);

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'\p{L}', unicode: true).hasMatch(w))
        .toList();
    if (words.isEmpty) return '#';
    String first(String w) =>
        RegExp(r'\p{L}', unicode: true).firstMatch(w)!.group(0)!;
    return (first(words.first) + (words.length > 1 ? first(words.last) : ''))
        .toUpperCase();
  }
}
