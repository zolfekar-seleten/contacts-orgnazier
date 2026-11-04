import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the OS share sheet (Save to Files, Mail, Drive…).
/// The app itself never uploads it anywhere.
abstract interface class FileSharer {
  /// Returns false when the user dismissed the share sheet.
  Future<bool> shareText({
    required String fileName,
    required String contents,
    required String mimeType,
    Rect? origin,
  });
}

class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<bool> shareText({
    required String fileName,
    required String contents,
    required String mimeType,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(contents), mimeType: mimeType)],
        fileNameOverrides: [fileName],
        subject: fileName,
        sharePositionOrigin: origin,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

final fileSharerProvider = Provider<FileSharer>(
  (ref) => const SharePlusFileSharer(),
);
