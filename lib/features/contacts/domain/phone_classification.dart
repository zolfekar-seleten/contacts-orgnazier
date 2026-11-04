/// Why a number could not be attributed to a country.
enum UnknownReason {
  /// National-format number and no default region to interpret it with.
  ambiguousNationalFormat,

  /// Parsed, but not a valid number for any region per libphonenumber metadata.
  invalid,

  /// Empty, too short or otherwise not a phone number.
  unparseable,
}

/// How the country of a classified number was determined.
enum ClassificationSource {
  /// The number carried an explicit `+` or exit code and country code.
  international,

  /// The platform supplied an E.164 normalization (Android).
  platformNormalized,

  /// A national-format number interpreted with the default region.
  defaultRegion,
}

/// Result of classifying a single phone number. Plain data so it can cross
/// isolate boundaries.
class PhoneClassification {
  const PhoneClassification.classified({
    required String this.isoCode,
    required String this.e164,
    required ClassificationSource this.source,
  }) : reason = null;

  const PhoneClassification.unknown(UnknownReason this.reason)
    : isoCode = null,
      e164 = null,
      source = null;

  /// ISO 3166-1 alpha-2 region, or null when unknown.
  final String? isoCode;

  /// Number in E.164 format (`+447911123456`), or null when unknown.
  final String? e164;

  final ClassificationSource? source;
  final UnknownReason? reason;

  bool get isClassified => isoCode != null;

  @override
  bool operator ==(Object other) =>
      other is PhoneClassification &&
      other.isoCode == isoCode &&
      other.e164 == e164 &&
      other.source == source &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(isoCode, e164, source, reason);

  @override
  String toString() => isClassified
      ? 'PhoneClassification($isoCode, $e164, ${source!.name})'
      : 'PhoneClassification.unknown(${reason!.name})';
}
