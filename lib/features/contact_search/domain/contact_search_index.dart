import '../../contacts/domain/app_contact.dart';
import '../../contacts/domain/contact_directory.dart';
import '../../countries/domain/country.dart';

/// Precomputed, lowercase search keys so each keystroke is a cheap scan.
class ContactSearchIndex {
  ContactSearchIndex(this.directory)
    : _entries = [for (final c in directory.contacts) _Entry.fromContact(c)];

  final ContactDirectory directory;
  final List<_Entry> _entries;

  /// Contacts matching [query] by name, phone digits or country, optionally
  /// restricted to [countryKey].
  List<AppContact> searchContacts(String query, {String? countryKey}) {
    final source = countryKey == null
        ? directory.contacts
        : directory.group(countryKey)?.contacts ?? const [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;

    final allowed = countryKey == null ? null : {for (final c in source) c.id};
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final digitQuery = qDigits.length >= 2 && qDigits.length * 2 >= q.length;

    return [
      for (final e in _entries)
        if ((allowed == null || allowed.contains(e.contact.id)) &&
            e.matches(q, digitQuery ? qDigits : null))
          e.contact,
    ];
  }

  /// Countries present in the directory whose name, ISO code or dialing code
  /// match [query].
  List<CountryGroup> searchCountries(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return directory.countries;
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    final isDialQuery = digits.isNotEmpty && RegExp(r'^\+?\d+$').hasMatch(q);
    return directory.countries.where((g) {
      final country = g.country!;
      if (isDialQuery) return country.dialCode.startsWith(digits);
      return matchesCountry(country, q);
    }).toList();
  }

  static bool matchesCountry(Country country, String lowerQuery) =>
      country.name.toLowerCase().contains(lowerQuery) ||
      country.isoCode.toLowerCase() == lowerQuery;
}

class _Entry {
  _Entry(this.contact, this.name, this.digits, this.countries);

  factory _Entry.fromContact(AppContact c) {
    final digits = <String>{};
    final countries = <Country>{};
    for (final p in c.phones) {
      digits.add(p.raw.replaceAll(RegExp(r'\D'), ''));
      final e164 = p.e164;
      if (e164 != null) digits.add(e164.substring(1));
      final country = p.country;
      if (country != null) countries.add(country);
    }
    return _Entry(c, c.displayName.toLowerCase(), digits.toList(), countries);
  }

  final AppContact contact;
  final String name;
  final List<String> digits;
  final Set<Country> countries;

  bool matches(String q, String? qDigits) {
    if (name.contains(q)) return true;
    if (qDigits != null && digits.any((d) => d.contains(qDigits))) {
      return true;
    }
    return countries.any((c) => ContactSearchIndex.matchesCountry(c, q));
  }
}
