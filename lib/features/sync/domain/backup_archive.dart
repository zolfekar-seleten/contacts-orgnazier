import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _dataEntry = 'data.json';
const _attachmentsDir = 'attachments/';

class InvalidBackupException implements Exception {
  const InvalidBackupException();

  @override
  String toString() => 'This file isn’t a Contacts Organizer backup.';
}

/// A backup: the snapshot JSON plus the activity images it refers to.
class BackupContents {
  const BackupContents({required this.snapshot, required this.attachments});

  final Map<String, dynamic> snapshot;

  /// File name → bytes.
  final Map<String, Uint8List> attachments;
}

/// Zips [contents] into one file.
Uint8List encodeBackup(BackupContents contents) {
  final archive = Archive();
  final json = utf8.encode(jsonEncode(contents.snapshot));
  archive.addFile(ArchiveFile(_dataEntry, json.length, json));
  for (final MapEntry(key: name, value: bytes)
      in contents.attachments.entries) {
    archive.addFile(ArchiveFile('$_attachmentsDir$name', bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

BackupContents decodeBackup(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const InvalidBackupException();
  }
  final data = archive.findFile(_dataEntry);
  if (data == null) throw const InvalidBackupException();
  final snapshot =
      jsonDecode(utf8.decode(data.content as List<int>))
          as Map<String, dynamic>;
  return BackupContents(
    snapshot: snapshot,
    attachments: {
      for (final f in archive.files)
        if (f.isFile && f.name.startsWith(_attachmentsDir))
          f.name.substring(_attachmentsDir.length): Uint8List.fromList(
            f.content as List<int>,
          ),
    },
  );
}
