import 'package:phone_numbers_parser/metadata.dart' show countryCodeToIsoCode;

import '../../contacts/domain/phone_classifier.dart';
import 'country_matcher.dart';

/// What a spreadsheet column holds.
enum ImportField {
  name('Full name'),
  firstName('First name'),
  lastName('Last name'),
  mobile('Mobile'),
  dialCode('Country code'),
  nationality('Nationality'),
  country('Country'),
  source('Source'),
  subSource('Sub source'),
  status('Status'),
  ignore('Don’t import');

  const ImportField(this.label);
  final String label;
}

/// A column's detected meaning and why.
class ColumnGuess {
  const ColumnGuess(this.field, {required this.byHeader});

  final ImportField field;

  /// Recognised from the header text (rather than only from the values).
  final bool byHeader;

  static const none = ColumnGuess(ImportField.ignore, byHeader: false);
}

/// The result of looking at a table: where the data starts and what each
/// column is.
class TableLayout {
  const TableLayout({required this.headerRow, required this.columns});

  /// Index of the header row, or null when the table has none.
  final int? headerRow;
  final List<ColumnGuess> columns;

  int get firstDataRow => (headerRow ?? -1) + 1;
}

/// Header words for each field, compared after removing case, spaces and
/// punctuation. Longer, more specific phrases are checked first.
const _headerWords = <ImportField, List<String>>{
  ImportField.subSource: [
    'subsource',
    'leadsubsource',
    'subchannel',
    'campaign',
    'campaignname',
    'referredby',
    'referrer',
    'المصدرالفرعي',
    'الحملة',
  ],
  ImportField.source: [
    'source',
    'leadsource',
    'channel',
    'origin',
    'howdidyouhear',
    'medium',
    'platform',
    'المصدر',
    'مصدر',
  ],
  ImportField.dialCode: [
    'countrycode',
    'dialcode',
    'callingcode',
    'phonecode',
    'mobilecode',
    'code',
    'cc',
    'prefix',
    'كودالدولة',
    'رمزالدولة',
    'مفتاحالدولة',
  ],
  ImportField.mobile: [
    'mobile',
    'mobileno',
    'mobilenumber',
    'phone',
    'phoneno',
    'phonenumber',
    'telephone',
    'tel',
    'cell',
    'cellphone',
    'contactno',
    'contactnumber',
    'number',
    'whatsapp',
    'whatsappnumber',
    'mob',
    'gsm',
    'الجوال',
    'جوال',
    'الهاتف',
    'هاتف',
    'الموبايل',
    'موبايل',
    'رقمالهاتف',
    'رقمالجوال',
    'رقم',
  ],
  ImportField.nationality: [
    'nationality',
    'citizenship',
    'nation',
    'nationalitycountry',
    'الجنسية',
    'جنسية',
  ],
  ImportField.country: [
    'country',
    'countryofresidence',
    'residence',
    'residencecountry',
    'location',
    'livingin',
    'basedin',
    'البلد',
    'الدولة',
    'دولة',
    'الإقامة',
    'بلدالإقامة',
  ],
  ImportField.firstName: [
    'firstname',
    'first',
    'given',
    'givenname',
    'fname',
    'forename',
    'الاسمالأول',
    'الاسمالاول',
  ],
  ImportField.lastName: [
    'lastname',
    'last',
    'family',
    'surname',
    'familyname',
    'lname',
    'اسمالعائلة',
    'العائلة',
  ],
  ImportField.name: [
    'name',
    'fullname',
    'clientname',
    'customername',
    'leadname',
    'contactname',
    'contact',
    'client',
    'customer',
    'lead',
    'الاسم',
    'اسم',
    'الاسمالكامل',
    'اسمالعميل',
  ],
  ImportField.status: [
    'status',
    'leadstatus',
    'stage',
    'temperature',
    'rating',
    'الحالة',
    'حالة',
  ],
};

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// The field a header names, or null.
ImportField? fieldForHeader(String header) {
  final h = _norm(header);
  if (h.isEmpty) return null;
  for (final MapEntry(key: field, value: words) in _headerWords.entries) {
    if (words.contains(h)) return field;
  }
  // Partial matches like "Customer Mobile No." or "Lead Source (2024)".
  for (final MapEntry(key: field, value: words) in _headerWords.entries) {
    for (final w in words) {
      if (w.length >= 5 && h.contains(w)) return field;
    }
  }
  return null;
}

/// Looks like a phone number: 7–15 digits, optionally `+`/`00`, with the
/// usual separators.
bool looksLikePhone(String s) {
  if (!RegExp(r'^[\s+()\-./\d٠-٩]+$').hasMatch(s)) return false;
  final digits = normalizePhoneInput(s).replaceAll('+', '');
  return digits.length >= 7 && digits.length <= 15;
}

/// Looks like a calling code: `971`, `+44`, `00 1`.
bool looksLikeDialCode(String s) {
  final t = s.trim().replaceFirst(RegExp(r'^(\+|00)'), '').trim();
  if (!RegExp(r'^\d{1,4}$').hasMatch(t)) return false;
  return countryCodeToIsoCode.containsKey(t);
}

bool _looksLikeName(String s) {
  final words = s.trim().split(RegExp(r'\s+'));
  return words.length <= 6 &&
      RegExp(r'\p{L}', unicode: true).hasMatch(s) &&
      !RegExp(r'\d{3,}').hasMatch(s) &&
      !s.contains('@');
}

/// Finds the header row (if any) and guesses every column.
TableLayout detectLayout(List<List<String>> rows) {
  if (rows.isEmpty) return const TableLayout(headerRow: null, columns: []);
  final width = rows.first.length;

  // The header is the row among the first few that names the most fields.
  int? headerRow;
  var bestHits = 0;
  for (var r = 0; r < rows.length && r < 10; r++) {
    final hits = rows[r].where((c) => fieldForHeader(c) != null).length;
    if (hits > bestHits) {
      bestHits = hits;
      headerRow = r;
    }
  }
  // A lone match only counts when that row has no data-looking values.
  if (bestHits == 1 && rows[headerRow!].any(looksLikePhone)) headerRow = null;

  final data = rows.skip((headerRow ?? -1) + 1).take(200).toList();
  final guesses = <ColumnGuess>[];
  for (var c = 0; c < width; c++) {
    final header = headerRow == null ? '' : rows[headerRow][c];
    final values = [
      for (final r in data)
        if (r[c].isNotEmpty) r[c],
    ];
    final byHeader = fieldForHeader(header);
    if (byHeader != null) {
      guesses.add(ColumnGuess(_refine(byHeader, values), byHeader: true));
    } else {
      guesses.add(ColumnGuess(_byValues(values), byHeader: false));
    }
  }
  return TableLayout(headerRow: headerRow, columns: _dedupe(guesses));
}

/// Headers can mislead ("Number" holding names); trust the values when they
/// clearly disagree for phone columns.
ImportField _refine(ImportField field, List<String> values) {
  if (values.isEmpty) return field;
  double share(bool Function(String) test) =>
      values.where(test).length / values.length;
  if (field == ImportField.mobile && share(looksLikeDialCode) > 0.8) {
    return ImportField.dialCode;
  }
  if (field == ImportField.dialCode && share(looksLikePhone) > 0.8) {
    return ImportField.mobile;
  }
  return field;
}

ImportField _byValues(List<String> values) {
  if (values.isEmpty) return ImportField.ignore;
  final matcher = CountryMatcher.instance;
  double share(bool Function(String) test) =>
      values.where(test).length / values.length;

  if (share(looksLikePhone) >= 0.6) return ImportField.mobile;
  if (share(looksLikeDialCode) >= 0.8) return ImportField.dialCode;
  if (share((v) => matcher.match(v) != null) >= 0.6) {
    return share(matcher.isNationalityWord) >= 0.5
        ? ImportField.nationality
        : ImportField.country;
  }
  if (share(_looksLikeName) >= 0.7) {
    // Few distinct short values (e.g. Hot/Cold) is a status, not a name.
    final distinct = values.map((v) => v.toLowerCase()).toSet();
    if (distinct.length <= 8 && values.length >= 8 * distinct.length / 2) {
      return ImportField.status;
    }
    return ImportField.name;
  }
  return ImportField.ignore;
}

/// Keeps one column per field: header matches win over value guesses, the
/// first column wins among equals. A full name beats first/last names.
List<ColumnGuess> _dedupe(List<ColumnGuess> guesses) {
  final result = [...guesses];
  for (final field in ImportField.values) {
    if (field == ImportField.ignore) continue;
    final idx = [
      for (var i = 0; i < result.length; i++)
        if (result[i].field == field) i,
    ];
    if (idx.length < 2) continue;
    final keep = idx.firstWhere(
      (i) => result[i].byHeader,
      orElse: () => idx.first,
    );
    for (final i in idx) {
      if (i == keep) continue;
      // Two country columns: the second is usually where they live.
      if (field == ImportField.nationality &&
          !result.any((g) => g.field == ImportField.country)) {
        result[i] = ColumnGuess(
          ImportField.country,
          byHeader: result[i].byHeader,
        );
        continue;
      }
      if (field == ImportField.country &&
          !result.any((g) => g.field == ImportField.nationality)) {
        result[i] = ColumnGuess(
          ImportField.nationality,
          byHeader: result[i].byHeader,
        );
        continue;
      }
      result[i] = ColumnGuess.none;
    }
  }
  // A guessed full name next to header-named first/last names is noise.
  final hasParts = result.any(
    (g) =>
        g.byHeader &&
        (g.field == ImportField.firstName || g.field == ImportField.lastName),
  );
  if (hasParts) {
    for (var i = 0; i < result.length; i++) {
      if (result[i].field == ImportField.name && !result[i].byHeader) {
        result[i] = ColumnGuess.none;
      }
    }
  }
  return result;
}
