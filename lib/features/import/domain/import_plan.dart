import 'package:drift/drift.dart' show Value;
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../contacts/domain/phone_classifier.dart';
import '../../crm/data/crm_database.dart';
import '../../crm/domain/party_phone.dart';
import 'column_detection.dart';
import 'country_matcher.dart';

enum RowOutcome { ready, duplicate, missingName }

/// One spreadsheet row turned into a lead or client.
class ImportRow {
  const ImportRow({
    required this.line,
    required this.outcome,
    required this.name,
    this.data,
    this.e164,
    this.statusName,
  });

  /// 1-based row number in the sheet, for messages.
  final int line;
  final RowOutcome outcome;
  final String name;
  final PartiesCompanion? data;
  final String? e164;

  /// Status text from the sheet, matched or created on import (leads only).
  final String? statusName;
}

/// What an import would do, shown before anything is saved.
class ImportPlan {
  const ImportPlan({required this.rows, required this.newStatuses});

  final List<ImportRow> rows;

  /// Status names in the sheet that don't exist yet and will be added.
  final List<String> newStatuses;

  Iterable<ImportRow> get ready =>
      rows.where((r) => r.outcome == RowOutcome.ready);
  int get duplicates =>
      rows.where((r) => r.outcome == RowOutcome.duplicate).length;
  int get missingName =>
      rows.where((r) => r.outcome == RowOutcome.missingName).length;
}

/// Converts [rows] (after the header) using [fields], one per column.
///
/// [existingNumbers] are E.164 numbers already saved, so re-importing a
/// sheet skips people it already added; duplicates inside the sheet are
/// skipped too. [defaultDialCode] applies to numbers written without a
/// country code. [statuses] maps existing status names (any case) to ids.
ImportPlan planImport({
  required List<List<String>> rows,
  required int firstDataRow,
  required List<ImportField> fields,
  required PartyKind kind,
  required Set<String> existingNumbers,
  required Map<String, String> statuses,
  String? defaultDialCode,
}) {
  String? cell(List<String> row, ImportField f) {
    final i = fields.indexOf(f);
    if (i < 0 || i >= row.length) return null;
    final v = row[i].trim();
    return v.isEmpty ? null : v;
  }

  final known = {for (final k in statuses.keys) k.toLowerCase()};
  final newStatuses = <String>[];
  final seen = {...existingNumbers};
  final result = <ImportRow>[];

  for (var r = firstDataRow; r < rows.length; r++) {
    final row = rows[r];
    final name = _name(
      cell(row, ImportField.name),
      cell(row, ImportField.firstName),
      cell(row, ImportField.lastName),
    );
    final phone = importPhone(
      cell(row, ImportField.mobile),
      dialCodeCell: cell(row, ImportField.dialCode),
      defaultDialCode: defaultDialCode,
    );
    final e164 = phone.national == null || phone.dialCode == null
        ? null
        : '+${phone.dialCode}${phone.national}';

    if (name == null) {
      result.add(
        ImportRow(line: r + 1, outcome: RowOutcome.missingName, name: ''),
      );
      continue;
    }
    if (e164 != null && !seen.add(e164)) {
      result.add(
        ImportRow(
          line: r + 1,
          outcome: RowOutcome.duplicate,
          name: name,
          e164: e164,
        ),
      );
      continue;
    }

    final matcher = CountryMatcher.instance;
    final status = kind == PartyKind.lead
        ? cell(row, ImportField.status)
        : null;
    if (status != null &&
        !known.contains(status.toLowerCase()) &&
        !newStatuses.any((s) => s.toLowerCase() == status.toLowerCase())) {
      newStatuses.add(status);
    }

    result.add(
      ImportRow(
        line: r + 1,
        outcome: RowOutcome.ready,
        name: name,
        e164: e164,
        statusName: status,
        data: PartiesCompanion.insert(
          kind: kind,
          name: name,
          dialCode: Value(phone.dialCode),
          mobile: Value(phone.national),
          nationality: Value(
            _country(cell(row, ImportField.nationality), matcher),
          ),
          country: Value(_country(cell(row, ImportField.country), matcher)),
          source: Value(cell(row, ImportField.source)),
          subSource: Value(cell(row, ImportField.subSource)),
        ),
      ),
    );
  }
  return ImportPlan(rows: result, newStatuses: newStatuses);
}

String? _name(String? full, String? first, String? last) {
  final joined = [?first, ?last].join(' ').trim();
  final name = (full ?? '').trim().isNotEmpty ? full!.trim() : joined;
  return name.isEmpty ? null : name.replaceAll(RegExp(r'\s+'), ' ');
}

String? _country(String? text, CountryMatcher matcher) =>
    text == null ? null : matcher.match(text);

/// Splits a spreadsheet phone value into calling code and national number.
///
/// Handles `+971 50…`, `00971…`, a separate code column (`971`, `+44`),
/// numbers saved without their `+` (`971501234567`, common when a sheet
/// stores phones as numbers) and local numbers using [defaultDialCode].
({String? dialCode, String? national}) importPhone(
  String? raw, {
  String? dialCodeCell,
  String? defaultDialCode,
}) {
  if (raw == null) return (dialCode: null, national: null);
  final columnCode = dialCodeCell
      ?.replaceAll(RegExp(r'\D'), '')
      .replaceFirst(RegExp(r'^00'), '');
  final digits = normalizePhoneInput(raw);

  if (!digits.startsWith('+') && !digits.startsWith('00')) {
    if (columnCode != null && columnCode.isNotEmpty) {
      return splitPhone(digits, dialCode: columnCode);
    }
    // A full international number missing its "+".
    if (digits.length >= 11) {
      try {
        final p = PhoneNumber.parse('+$digits');
        if (p.isValid()) return (dialCode: p.countryCode, national: p.nsn);
      } on PhoneNumberException {
        // Not international; treat it as local below.
      }
    }
  }
  return splitPhone(raw, dialCode: columnCode ?? defaultDialCode);
}
