import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file in the iCloud container.
class CloudFile {
  const CloudFile({
    required this.name,
    required this.size,
    required this.modified,
    required this.downloaded,
  });

  final String name;
  final int size;
  final DateTime modified;

  /// False while it only exists in iCloud (it downloads on demand).
  final bool downloaded;
}

class CloudUnavailableException implements Exception {
  const CloudUnavailableException([this.message]);
  final String? message;

  @override
  String toString() =>
      message ??
      'iCloud isn’t available. Sign in to iCloud with iCloud Drive on.';
}

/// The app's iCloud Drive container. Paths are relative to it:
/// `Documents/Backups/…` is visible in the Files app, `Sync/…` is not.
abstract interface class CloudFiles {
  Future<bool> isAvailable();
  Future<void> upload(String localPath, String remotePath);
  Future<List<CloudFile>> list(String dir);
  Future<void> download(String remotePath, String localPath);
  Future<void> delete(String remotePath);
}

/// The native iOS implementation (see `AppDelegate.swift`). Other platforms
/// report iCloud as unavailable.
class ChannelCloudFiles implements CloudFiles {
  const ChannelCloudFiles();

  static const _channel = MethodChannel('contacts_organizer/icloud');

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (!_supported) throw const CloudUnavailableException();
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') throw CloudUnavailableException(e.message);
      rethrow;
    } on MissingPluginException {
      throw const CloudUnavailableException();
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (!_supported) return false;
    try {
      return await _call<bool>('isAvailable') ?? false;
    } on CloudUnavailableException {
      return false;
    }
  }

  @override
  Future<void> upload(String localPath, String remotePath) =>
      _call<void>('upload', {'localPath': localPath, 'remotePath': remotePath});

  @override
  Future<List<CloudFile>> list(String dir) async {
    final rows = await _call<List<Object?>>('list', {'dir': dir}) ?? const [];
    return [
      for (final r in rows.cast<Map<Object?, Object?>>())
        CloudFile(
          name: r['name']! as String,
          size: (r['size'] as num?)?.toInt() ?? 0,
          modified: DateTime.fromMillisecondsSinceEpoch(
            (r['modified'] as num?)?.toInt() ?? 0,
          ),
          downloaded: r['downloaded'] as bool? ?? true,
        ),
    ];
  }

  @override
  Future<void> download(String remotePath, String localPath) => _call<void>(
    'download',
    {'remotePath': remotePath, 'localPath': localPath},
  );

  @override
  Future<void> delete(String remotePath) =>
      _call<void>('delete', {'remotePath': remotePath});
}

/// A plain folder standing in for iCloud, for tests (and to share between
/// simulated devices).
class FolderCloudFiles implements CloudFiles {
  FolderCloudFiles(this.root, {this.available = true});

  final Directory root;
  bool available;

  File _file(String path) => File('${root.path}/$path');

  void _check() {
    if (!available) throw const CloudUnavailableException();
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> upload(String localPath, String remotePath) async {
    _check();
    final f = _file(remotePath);
    await f.parent.create(recursive: true);
    await File(localPath).copy(f.path);
  }

  @override
  Future<List<CloudFile>> list(String dir) async {
    _check();
    final d = Directory('${root.path}/$dir');
    if (!await d.exists()) return const [];
    return [
      await for (final e in d.list())
        if (e is File)
          CloudFile(
            name: e.uri.pathSegments.last,
            size: await e.length(),
            modified: await e.lastModified(),
            downloaded: true,
          ),
    ];
  }

  @override
  Future<void> download(String remotePath, String localPath) async {
    _check();
    await _file(remotePath).copy(localPath);
  }

  @override
  Future<void> delete(String remotePath) async {
    _check();
    final f = _file(remotePath);
    if (await f.exists()) await f.delete();
  }
}
