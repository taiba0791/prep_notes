import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_picker.g.dart';

enum PhotoSource { gallery, camera }

/// A picked photo, already shrunk for upload.
typedef PickedPhoto = ({Uint8List bytes, String contentType});

/// Lets the user choose a photo. Wrapped so tests can swap in a fake.
abstract interface class PhotoPicker {
  /// Returns null if the user cancelled.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Avatars are shown small; 512 px is plenty and keeps uploads ~50–150 KB.
  static const maxSize = 512.0;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxSize,
      maxHeight: maxSize,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return (
      bytes: await file.readAsBytes(),
      contentType: file.mimeType ?? 'image/jpeg',
    );
  }
}

@Riverpod(keepAlive: true)
PhotoPicker photoPicker(Ref ref) => ImagePickerPhotoPicker();
