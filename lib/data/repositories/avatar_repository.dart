import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_paths.dart';
import '../../core/providers/firebase_providers.dart';

part 'avatar_repository.g.dart';

/// Profile photos in Storage at `avatars/{uid}/avatar.jpg`.
/// storage.rules: owner-only writes, images only, < 2 MB; public reads.
abstract interface class AvatarRepository {
  /// Max upload size, matching storage.rules.
  static const maxBytes = 2 * 1024 * 1024;

  /// Uploads (replacing any old photo) and returns its public URL.
  Future<String> upload(String uid, Uint8List bytes, {String contentType});

  /// Deletes the photo. Does nothing if there is none.
  Future<void> delete(String uid);
}

class FirebaseAvatarRepository implements AvatarRepository {
  FirebaseAvatarRepository(this._storage);

  final FirebaseStorage _storage;

  Reference _ref(String uid) => _storage.ref(StoragePaths.avatar(uid));

  @override
  Future<String> upload(
    String uid,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final ref = _ref(uid);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=86400',
      ),
    );
    final url = await ref.getDownloadURL();
    // Same file name every time → add a version so caches show the new photo.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> delete(String uid) async {
    try {
      await _ref(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
AvatarRepository avatarRepository(Ref ref) =>
    FirebaseAvatarRepository(ref.watch(firebaseStorageProvider));
