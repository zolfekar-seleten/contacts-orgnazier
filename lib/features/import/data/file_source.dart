import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PickedFile = ({String name, Uint8List bytes});

/// Lets the user choose a spreadsheet; behind an interface for tests.
abstract interface class SpreadsheetSource {
  /// Null when the user cancels.
  Future<PickedFile?> pick();
}

class FilePickerSpreadsheetSource implements SpreadsheetSource {
  const FilePickerSpreadsheetSource();

  @override
  Future<PickedFile?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv', 'txt', 'tsv', 'xls'],
    );
    final file = files.firstOrNull;
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }
}

final spreadsheetSourceProvider = Provider<SpreadsheetSource>(
  (ref) => const FilePickerSpreadsheetSource(),
);
