import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// One sheet of a spreadsheet as plain text cells.
class ImportTable {
  const ImportTable({required this.name, required this.rows});

  final String name;

  /// Non-empty rows, all padded to the same width.
  final List<List<String>> rows;

  int get width => rows.isEmpty ? 0 : rows.first.length;
}

class UnsupportedFileException implements Exception {
  const UnsupportedFileException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads `.xlsx` workbooks (every sheet with data) and `.csv`/`.txt` files.
List<ImportTable> readSpreadsheet(String fileName, Uint8List bytes) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'xlsx' => _readXlsx(bytes),
    'csv' ||
    'txt' ||
    'tsv' => [ImportTable(name: fileName, rows: _tidy(_readCsv(bytes)))],
    'xls' => throw const UnsupportedFileException(
      'Old .xls files aren’t supported. In Excel, choose File › Save As › '
      'Excel Workbook (.xlsx) or CSV, then import that.',
    ),
    _ => throw const UnsupportedFileException(
      'Choose an Excel (.xlsx) or CSV file.',
    ),
  }.where((t) => t.rows.isNotEmpty).toList();
}

List<ImportTable> _readXlsx(Uint8List bytes) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const UnsupportedFileException(
      'This file couldn’t be read as an Excel workbook.',
    );
  }
  return [
    for (final MapEntry(key: name, value: sheet) in book.tables.entries)
      ImportTable(
        name: name,
        rows: _tidy([
          for (final row in sheet.rows) [for (final c in row) _cell(c?.value)],
        ]),
      ),
  ];
}

/// Cell text as a person would read it; whole numbers lose their `.0` so a
/// phone number stored as a number stays intact.
String _cell(CellValue? v) => switch (v) {
  null => '',
  TextCellValue(:final value) => value.toString(),
  IntCellValue(:final value) => '$value',
  DoubleCellValue(:final value) =>
    value == value.roundToDouble() && value.abs() < 1e15
        ? value.toStringAsFixed(0)
        : '$value',
  DateCellValue(:final year, :final month, :final day) =>
    '$year-${'$month'.padLeft(2, '0')}-${'$day'.padLeft(2, '0')}',
  _ => v.toString(),
}.trim();

List<List<String>> _readCsv(Uint8List bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    // Older Excel CSV exports are often Windows-1252 / Latin-1.
    text = latin1.decode(bytes);
  }
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return [
    for (final row in Csv().decode(text)) [for (final c in row) '$c'.trim()],
  ];
}

/// Drops empty rows and trailing empty columns, then pads rows to one width.
List<List<String>> _tidy(List<List<String>> rows) {
  final kept = [
    for (final r in rows)
      if (r.any((c) => c.isNotEmpty)) r,
  ];
  var width = 0;
  for (final r in kept) {
    final last = r.lastIndexWhere((c) => c.isNotEmpty);
    if (last + 1 > width) width = last + 1;
  }
  return [
    for (final r in kept)
      [for (var i = 0; i < width; i++) i < r.length ? r[i] : ''],
  ];
}
