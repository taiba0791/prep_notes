import 'dart:typed_data';

import 'package:prepnotes/core/services/file_picker_service.dart';
import 'package:prepnotes/core/services/photo_picker.dart';
import 'package:prepnotes/data/repositories/avatar_repository.dart';
import 'package:prepnotes/data/repositories/note_repository.dart';

/// Returns [nextPdf] / [nextImage] (null = cancelled).
class FakeFilePickerService implements FilePickerService {
  PickedFile? nextPdf;
  PickedFile? nextImage;

  @override
  Future<PickedFile?> pickPdf() async => nextPdf;

  @override
  Future<PickedFile?> pickImage() async => nextImage;

  @override
  Future<PickedFile?> pickPdfOrImage() async => nextPdf ?? nextImage;
}

/// Records uploads in memory.
class FakeCatalogFilesRepository implements CatalogFilesRepository {
  final uploads = <String>[];

  @override
  Future<String> uploadNotePdf(
    String noteId,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1);
    uploads.add('pdf:$noteId');
    return 'notes_private/$noteId/file.pdf';
  }

  @override
  Future<String> uploadNoteThumbnail(
    String noteId,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add('thumb:$noteId');
    return 'https://storage.test/notes_public/$noteId/thumbnail.jpg';
  }

  @override
  Future<String> uploadUniversityLogo(
    String universityId,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add('logo:$universityId');
    return 'https://storage.test/universities/$universityId/logo';
  }
}

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
