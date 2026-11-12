import 'dart:convert';
import 'dart:typed_data';

import 'package:country_contacts/features/crm/data/crm_database.dart';
import 'package:country_contacts/features/import/domain/column_detection.dart';
import 'package:country_contacts/features/import/domain/country_matcher.dart';
import 'package:country_contacts/features/import/domain/import_plan.dart';
import 'package:country_contacts/features/import/domain/table_reader.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

List<ImportField> fieldsOf(List<List<String>> rows) =>
    detectLayout(rows).columns.map((c) => c.field).toList();

void main() {
  group('reading files', () {
    test('CSV with a BOM, semicolons and quoted commas', () {
      final csv =
          '﻿Name;Mobile;Note\r\n'
          '"Khan, Sara";+971 50 123 4567;"likes ""sea"" view"\r\n'
          '\r\n'
          'Omar;0501112222;\r\n';
      final [table] = readSpreadsheet(
        'leads.csv',
        Uint8List.fromList(utf8.encode(csv)),
      );
      expect(table.rows, [
        ['Name', 'Mobile', 'Note'],
        ['Khan, Sara', '+971 50 123 4567', 'likes "sea" view'],
        ['Omar', '0501112222', ''],
      ]);
    });

    test('xlsx keeps phone numbers stored as numbers intact', () {
      final book = Excel.createExcel();
      final sheet = book.getDefaultSheet()!;
      book.appendRow(sheet, [TextCellValue('Name'), TextCellValue('Phone')]);
      book.appendRow(sheet, [
        TextCellValue('Sara'),
        DoubleCellValue(971501234567),
      ]);
      book.appendRow(sheet, [
        TextCellValue('Omar'),
        IntCellValue(447400123456),
      ]);
      final tables = readSpreadsheet(
        'leads.xlsx',
        Uint8List.fromList(book.encode()!),
      );
      expect(tables.single.rows, [
        ['Name', 'Phone'],
        ['Sara', '971501234567'],
        ['Omar', '447400123456'],
      ]);
    });

    test('old .xls files get a helpful message', () {
      expect(
        () => readSpreadsheet('old.xls', Uint8List(4)),
        throwsA(isA<UnsupportedFileException>()),
      );
    });
  });

  group('country matching', () {
    final m = CountryMatcher.instance;
    test('names, codes, abbreviations, nationalities and Arabic', () {
      expect(m.match('United Arab Emirates'), 'AE');
      expect(m.match('U.A.E.'), 'AE');
      expect(m.match('uae'), 'AE');
      expect(m.match('Emirati'), 'AE');
      expect(m.match('الإمارات'), 'AE');
      expect(m.match('KSA'), 'SA');
      expect(m.match('british'), 'GB');
      expect(m.match('UK'), 'GB');
      expect(m.match('in'), 'IN');
      expect(m.match('Côte d’Ivoire'), isNotNull);
      expect(m.match('Mars'), isNull);
    });
  });

  group('column detection', () {
    test('recognises everyday and messy header names', () {
      expect(
        fieldsOf([
          [
            'Customer Name',
            'Mobile No.',
            'Nationality',
            'Country of Residence',
            'Lead Source',
            'Campaign',
            'Status',
            'Notes',
          ],
          [
            'Sara',
            '0501234567',
            'Indian',
            'UAE',
            'Instagram',
            'Ramadan',
            'Hot',
            'x',
          ],
        ]),
        [
          ImportField.name,
          ImportField.mobile,
          ImportField.nationality,
          ImportField.country,
          ImportField.source,
          ImportField.subSource,
          ImportField.status,
          ImportField.ignore,
        ],
      );
    });

    test('Arabic headers', () {
      expect(
        fieldsOf([
          ['الاسم', 'الجوال', 'الجنسية', 'المصدر'],
          ['سارة', '0501234567', 'هندي', 'انستغرام'],
        ]),
        [
          ImportField.name,
          ImportField.mobile,
          ImportField.nationality,
          ImportField.source,
        ],
      );
    });

    test('finds the header below a title row', () {
      final layout = detectLayout([
        ['Leads export – November', '', ''],
        ['First Name', 'Last Name', 'Phone'],
        ['Sara', 'Khan', '+971501234567'],
      ]);
      expect(layout.headerRow, 1);
      expect(layout.columns.map((c) => c.field), [
        ImportField.firstName,
        ImportField.lastName,
        ImportField.mobile,
      ]);
    });

    test('no header: reads the values', () {
      final rows = [
        ['Sara Khan', '+971 50 123 4567', 'India', 'Hot'],
        ['Omar Haddad', '00447400123456', 'United Kingdom', 'Cold'],
        ['Priya Nair', '0501112222', 'India', 'Hot'],
        ['Ali Raza', '0502223333', 'Pakistan', 'Cold'],
        ['John Smith', '0503334444', 'USA', 'Hot'],
        ['Mona Saleh', '0504445555', 'Egypt', 'Cold'],
        ['Fatima Ali', '0505556666', 'UAE', 'Hot'],
        ['Rami Odeh', '0506667777', 'Jordan', 'Cold'],
      ];
      final layout = detectLayout(rows);
      expect(layout.headerRow, isNull);
      expect(layout.columns.map((c) => c.field), [
        ImportField.name,
        ImportField.mobile,
        ImportField.country,
        ImportField.status,
      ]);
    });

    test('a separate country code column', () {
      expect(
        fieldsOf([
          ['Name', 'Code', 'Number'],
          ['Sara', '+971', '501234567'],
          ['Omar', '44', '7400123456'],
        ]),
        [ImportField.name, ImportField.dialCode, ImportField.mobile],
      );
    });

    test('nationality words in an unnamed column', () {
      expect(
        fieldsOf([
          ['Name', 'Phone', 'Info'],
          ['Sara', '0501234567', 'Indian'],
          ['Omar', '0501234568', 'British'],
          ['Ali', '0501234569', 'Pakistani'],
        ]),
        [ImportField.name, ImportField.mobile, ImportField.nationality],
      );
    });
  });

  group('phone values', () {
    test('international, 00, missing +, code column and local', () {
      expect(importPhone('+971 50 123 4567'), (
        dialCode: '971',
        national: '501234567',
      ));
      expect(importPhone('00447400123456'), (
        dialCode: '44',
        national: '7400123456',
      ));
      expect(importPhone('971501234567'), (
        dialCode: '971',
        national: '501234567',
      ));
      expect(importPhone('501234567', dialCodeCell: '+971'), (
        dialCode: '971',
        national: '501234567',
      ));
      expect(importPhone('050 123 4567', defaultDialCode: '971'), (
        dialCode: '971',
        national: '501234567',
      ));
      expect(importPhone(null), (dialCode: null, national: null));
    });
  });

  group('import plan', () {
    final rows = [
      ['Name', 'First', 'Last', 'Mobile', 'Nationality', 'Country', 'Status'],
      ['Sara Khan', '', '', '+971501234567', 'Indian', 'UAE', 'hot'],
      ['', 'Omar', 'Haddad', '0501112222', 'Jordanian', 'Dubai', 'Viewing'],
      ['Sara again', '', '', '00971501234567', '', '', ''],
      ['', '', '', '0503334444', '', '', ''],
      ['Already saved', '', '', '+447400123456', '', '', ''],
    ];

    ImportPlan plan(PartyKind kind) => planImport(
      rows: rows,
      firstDataRow: 1,
      fields: detectLayout(rows).columns.map((c) => c.field).toList(),
      kind: kind,
      existingNumbers: {'+447400123456'},
      statuses: {'Cold': 'c', 'Hot': 'h'},
      defaultDialCode: '971',
    );

    test('ready, duplicate and nameless rows are told apart', () {
      final p = plan(PartyKind.lead);
      expect(p.ready.map((r) => r.name), ['Sara Khan', 'Omar Haddad']);
      expect(p.duplicates, 2); // repeated in the sheet, and already saved
      expect(p.missingName, 1);
      expect(
        p.rows.firstWhere((r) => r.outcome == RowOutcome.missingName).line,
        5,
      );
    });

    test('values are cleaned up', () {
      final [sara, omar] = plan(PartyKind.lead).ready.toList();
      expect(sara.data!.dialCode.value, '971');
      expect(sara.data!.mobile.value, '501234567');
      expect(sara.data!.nationality.value, 'IN');
      expect(sara.data!.country.value, 'AE');
      expect(omar.data!.mobile.value, '501112222'); // local, default +971
      expect(omar.data!.nationality.value, 'JO');
      expect(omar.data!.country.value, 'AE'); // "Dubai"
    });

    test('unknown statuses are added; known ones match any case', () {
      final p = plan(PartyKind.lead);
      expect(p.newStatuses, ['Viewing']);
      expect(p.ready.first.statusName, 'hot');
    });

    test('clients ignore the status column', () {
      final p = plan(PartyKind.client);
      expect(p.newStatuses, isEmpty);
      expect(
        p.ready.every((r) => r.data!.kind.value == PartyKind.client),
        isTrue,
      );
    });
  });
}
