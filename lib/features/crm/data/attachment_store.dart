import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps activity images as files in the app's documents folder (included
/// in device backups), named by UUID so they never collide across devices.
class AttachmentStore {
  AttachmentStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _root;
  Directory? _dir;

  Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final dir = Directory('${(await _root()).path}/attachments');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Copies [image] in and returns its stored file name.
  Future<String> save(XFile image) async {
    final ext = image.name.contains('.')
        ? image.name.substring(image.name.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final name = '${const Uuid().v4()}$ext';
    await image.saveTo('${(await _folder()).path}/$name');
    return name;
  }

  Future<File> file(String name) async =>
      File('${(await _folder()).path}/$name');

  Future<void> delete(String name) async {
    final f = await file(name);
    if (await f.exists()) await f.delete();
  }
}

/// Photo library and camera access, behind an interface for tests.
abstract interface class ImageSourceGateway {
  Future<List<XFile>> pickFromLibrary();
  Future<XFile?> takePhoto();
}

class ImagePickerGateway implements ImageSourceGateway {
  ImagePickerGateway([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<XFile>> pickFromLibrary() =>
      _picker.pickMultiImage(maxWidth: 2048, imageQuality: 85);

  @override
  Future<XFile?> takePhoto() => _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 2048,
    imageQuality: 85,
  );
}
