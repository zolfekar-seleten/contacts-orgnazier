import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'phone_classification.dart';

/// Strips formatting from a dialable phone string.
///
/// Keeps digits and a leading `+`, converts Arabic-Indic and Persian digits to
/// ASCII, and drops extensions / pause sequences (`,` `;` `#` `x` `ext`).
String normalizePhoneInput(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.writeCharCode(rune);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30);
    } else if ((rune == 0x2B || rune == 0xFF0B) && buffer.isEmpty) {
      buffer.write('+');
    } else if (const {0x2C, 0x3B, 0x23, 0x78, 0x58, 0x65}.contains(rune) &&
        buffer.isNotEmpty) {
      // ',' ';' '#' 'x' 'X' 'e' (ext): the rest is an extension or DTMF.
      break;
    }
  }
  return buffer.toString();
}

/// Classifies phone numbers by country using libphonenumber metadata.
///
/// National-format numbers (no `+` / exit code) are only classified when a
/// [defaultRegion] is provided or the platform supplied an E.164 normalization;
/// otherwise they are reported as [UnknownReason.ambiguousNationalFormat]
/// rather than guessed.
class PhoneClassifier {
  PhoneClassifier({String? defaultRegion})
    : defaultRegion = _parseIso(defaultRegion);

  final IsoCode? defaultRegion;
  final Map<String, PhoneClassification> _cache = {};

  int get cacheSize => _cache.length;

  static String cacheKey(String raw, String? platformNormalized) =>
      '$raw\u0000${platformNormalized ?? ''}';

  bool isCached(String raw, String? platformNormalized) =>
      _cache.containsKey(cacheKey(raw, platformNormalized));

  /// Seeds the cache with results computed elsewhere (e.g. in an isolate).
  void putAll(Map<String, PhoneClassification> results) =>
      _cache.addAll(results);

  PhoneClassification classify(String raw, {String? platformNormalized}) =>
      _cache[cacheKey(raw, platformNormalized)] ??= classifyUncached(
        raw,
        platformNormalized: platformNormalized,
        defaultRegion: defaultRegion,
      );

  static PhoneClassification classifyUncached(
    String raw, {
    String? platformNormalized,
    IsoCode? defaultRegion,
  }) {
    final cleaned = normalizePhoneInput(raw);
    final digitCount = cleaned.replaceAll('+', '').length;
    if (digitCount < 3) {
      return const PhoneClassification.unknown(UnknownReason.unparseable);
    }

    if (cleaned.startsWith('+')) {
      return _parse(cleaned, source: ClassificationSource.international);
    }

    if (defaultRegion != null) {
      if (_hasExitCode(cleaned, defaultRegion)) {
        return _parse(
          cleaned,
          callerCountry: defaultRegion,
          source: ClassificationSource.international,
        );
      }
      // A national number may belong to any region sharing the caller's
      // numbering plan (e.g. US/CA under +1, GB/GG/JE/IM under +44).
      final countryCode = metadataByIsoCode[defaultRegion]!.countryCode;
      final candidates = {defaultRegion, ...?countryCodeToIsoCode[countryCode]};
      for (final destination in candidates) {
        final result = _parse(
          cleaned,
          callerCountry: defaultRegion,
          destinationCountry: destination,
          source: ClassificationSource.defaultRegion,
        );
        if (result.isClassified) return result;
      }
    }

    final normalized = platformNormalized == null
        ? ''
        : normalizePhoneInput(platformNormalized);
    if (normalized.startsWith('+')) {
      return _parse(
        normalized,
        source: ClassificationSource.platformNormalized,
      );
    }

    if (defaultRegion == null) {
      // "00" is the ITU-recommended international prefix and is not a valid
      // start for national numbers in regions that use it, so it is safe to
      // treat as international even without knowing the caller's region.
      if (cleaned.startsWith('00')) {
        return _parse(
          '+${cleaned.substring(2)}',
          source: ClassificationSource.international,
        );
      }
      return const PhoneClassification.unknown(
        UnknownReason.ambiguousNationalFormat,
      );
    }
    return const PhoneClassification.unknown(UnknownReason.invalid);
  }

  static bool _hasExitCode(String cleaned, IsoCode region) {
    final prefix = metadataByIsoCode[region]?.internationalPrefix;
    if (prefix == null) return cleaned.startsWith('00');
    return RegExp('^(?:$prefix)').hasMatch(cleaned);
  }

  static PhoneClassification _parse(
    String input, {
    IsoCode? callerCountry,
    IsoCode? destinationCountry,
    required ClassificationSource source,
  }) {
    try {
      final number = PhoneNumber.parse(
        input,
        callerCountry: callerCountry,
        destinationCountry: destinationCountry,
      );
      if (!number.isValid()) {
        return const PhoneClassification.unknown(UnknownReason.invalid);
      }
      return PhoneClassification.classified(
        isoCode: number.isoCode.name,
        e164: number.international,
        source: source,
      );
    } on PhoneNumberException {
      return const PhoneClassification.unknown(UnknownReason.invalid);
    }
  }

  static IsoCode? _parseIso(String? iso) {
    if (iso == null) return null;
    final upper = iso.toUpperCase();
    for (final code in IsoCode.values) {
      if (code.name == upper) return code;
    }
    return null;
  }
}
