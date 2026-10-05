import 'dart:typed_data';

import 'package:prepnotes/core/services/photo_picker.dart';
import 'package:prepnotes/data/repositories/avatar_repository.dart';

/// Returns [next] (or null = cancelled) instead of opening a real picker.
class FakePhotoPicker implements PhotoPicker {
  PickedPhoto? next;
  final sources = <PhotoSource>[];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    sources.add(source);
    return next;
  }
}

/// Keeps "uploaded" files in memory.
class FakeAvatarRepository implements AvatarRepository {
  final files = <String, Uint8List>{};
  Object? nextError;

  @override
  Future<String> upload(
    String uid,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final e = nextError;
    nextError = null;
    if (e != null) throw e;
    files[uid] = bytes;
    return 'https://storage.test/avatars/$uid/avatar.jpg';
  }

  @override
  Future<void> delete(String uid) async => files.remove(uid);
}
