import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_service.g.dart';

/// A file chosen by the admin, read into memory.
typedef PickedFile = ({String name, Uint8List bytes, String contentType});

/// Choosing PDFs / images (admin uploads). Wrapped so tests can fake it.
abstract interface class FilePickerService {
  /// Returns null if the user cancelled.
  Future<PickedFile?> pickPdf();

  /// JPG / PNG / WEBP. Returns null if the user cancelled.
  Future<PickedFile?> pickImage();
}

class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  static const _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  @override
  Future<PickedFile?> pickPdf() => _pick(['pdf'], (_) => 'application/pdf');

  @override
  Future<PickedFile?> pickImage() => _pick(
    _imageTypes.keys.toList(),
    (ext) => _imageTypes[ext] ?? 'image/jpeg',
  );

  Future<PickedFile?> _pick(
    List<String> extensions,
    String Function(String ext) contentType,
  ) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    final ext = (file.extension ?? '').replaceFirst('.', '').toLowerCase();
    return (
      name: file.name,
      bytes: await file.readAsBytes(),
      contentType: contentType(ext),
    );
  }
}

@Riverpod(keepAlive: true)
FilePickerService filePickerService(Ref ref) =>
    const PlatformFilePickerService();
