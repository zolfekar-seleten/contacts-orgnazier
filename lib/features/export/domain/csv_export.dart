import '../../contacts/domain/app_contact.dart';

const csvHeader = [
  'First name',
  'Last name',
  'Full name',
  'Phone',
  'Phone as saved',
  'Label',
  'Country',
  'Dial code',
];

/// One row per phone number of [contacts]; only numbers from [countryKey]
/// when given. Starts with a UTF-8 BOM so Excel reads non-Latin names, and
/// uses CRLF line endings as RFC 4180 specifies.
String contactsToCsv(List<AppContact> contacts, {String? countryKey}) {
  final rows = [
    csvHeader,
    for (final c in contacts)
      for (final p in c.phonesFor(countryKey))
        [
          c.firstName,
          c.lastName,
          c.displayName,
          p.e164 ?? p.raw.trim(),
          p.raw.trim(),
          p.label,
          p.country?.name ?? 'Unknown',
          p.country?.formattedDialCode ?? '',
        ],
  ];
  return '﻿${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
}

/// `Contacts Organizer - United Kingdom - 2026-11-04.csv`
String csvFileName(String scope, DateTime date) {
  final day =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final safeScope = scope.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  return 'Contacts Organizer - $safeScope - $day.csv';
}

String _cell(String value) {
  // Spreadsheets treat a leading = + - @ as a formula, which would turn
  // "+44 7400 123456" into an error and lets a crafted name run a formula.
  // A leading tab keeps the cell as plain text.
  final v = RegExp(r'^[=+\-@]').hasMatch(value) ? '\t$value' : value;
  return RegExp(r'[",\r\n\t]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
}
