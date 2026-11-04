import 'dart:typed_data';

import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../countries/domain/country.dart';
import 'phone_classification.dart';

/// A device phone number together with its country classification.
class ClassifiedPhone {
  ClassifiedPhone({
    required this.raw,
    required this.label,
    required this.classification,
  });

  /// The number exactly as stored on the device.
  final String raw;
  final String label;
  final PhoneClassification classification;

  Country? get country => Country.fromIso(classification.isoCode);
  String? get e164 => classification.e164;

  PhoneNumber? get _parsed {
    final e164 = this.e164;
    if (e164 == null) return null;
    try {
      return PhoneNumber.parse(e164);
    } on PhoneNumberException {
      return null;
    }
  }

  /// Compact, consistent international form for lists (`+44 7400 123456`);
  /// falls back to [raw] for numbers that couldn't be classified. Computed
  /// once, on first display.
  late final String display = switch (_parsed) {
    final p? =>
      '+${p.countryCode} ${p.formatNsn(format: NsnFormat.international)}',
    null => raw.trim(),
  };

  /// Whether numbering-plan metadata says this is a mobile number. Labels
  /// are unreliable, so this is what "prefer mobile" decisions use.
  late final bool isMobile =
      _parsed?.isValid(type: PhoneNumberType.mobile) ?? false;
}

/// A contact with classified phone numbers, ready for display.
class AppContact {
  AppContact({
    required this.id,
    required this.displayName,
    required this.phones,
    this.thumbnail,
    String? firstName,
    String? lastName,
  }) : firstName = _firstName(firstName, displayName),
       lastName = _lastName(firstName, lastName, displayName),
       countryKeys = {
         for (final p in phones)
           p.classification.isoCode ?? CountryGroup.unknownKey,
       };

  final String id;
  final String displayName;
  final List<ClassifiedPhone> phones;
  final Uint8List? thumbnail;

  /// Given name; falls back to the first word of [displayName].
  final String firstName;

  /// Family name; falls back to the remaining words of [displayName] when no
  /// structured name exists. May be empty.
  final String lastName;

  /// Name-like words only, so a number used as display name is not a name.
  static List<String> _words(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(w))
      .toList();

  static String _firstName(String? first, String display) {
    final f = first?.trim() ?? '';
    if (f.isNotEmpty) return f;
    final words = _words(display);
    return words.isEmpty ? '' : words.first;
  }

  static String _lastName(String? first, String? last, String display) {
    final l = last?.trim() ?? '';
    if (l.isNotEmpty) return l;
    // A structured first name without a last name means there is none.
    if ((first?.trim() ?? '').isNotEmpty) return '';
    final words = _words(display);
    return words.length < 2 ? '' : words.skip(1).join(' ');
  }

  /// ISO codes of this contact's numbers ([CountryGroup.unknownKey] for
  /// numbers that could not be classified).
  final Set<String> countryKeys;

  String get initials {
    // First letter of the first and last name-like words, so "(Work)" gives
    // "W" rather than "(".
    final letters = [
      for (final w in _words(displayName))
        RegExp(r'\p{L}', unicode: true).firstMatch(w)!.group(0)!,
    ];
    if (letters.isEmpty) return '#';
    return (letters.first + (letters.length > 1 ? letters.last : ''))
        .toUpperCase();
  }

  /// The number to show in lists: a mobile number when there is one
  /// (from [countryKey] if given), otherwise the first number.
  ClassifiedPhone? primaryPhone([String? countryKey]) {
    final pool = phonesFor(countryKey);
    if (pool.isEmpty) return null;
    for (final p in pool) {
      if (p.isMobile) return p;
    }
    return pool.first;
  }

  /// Phones belonging to [countryKey], or all phones when null.
  List<ClassifiedPhone> phonesFor(String? countryKey) => countryKey == null
      ? phones
      : phones
            .where(
              (p) =>
                  (p.classification.isoCode ?? CountryGroup.unknownKey) ==
                  countryKey,
            )
            .toList();
}

/// Contacts grouped under a single country (or the Unknown bucket).
class CountryGroup {
  const CountryGroup({required this.key, required this.contacts});

  /// `ZZ` is libphonenumber's code for an unknown region.
  static const unknownKey = 'ZZ';

  final String key;
  final List<AppContact> contacts;

  Country? get country => Country.fromIso(key);
  bool get isUnknown => key == unknownKey;
  int get count => contacts.length;
}
