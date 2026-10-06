import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

part 'file_download.g.dart';

/// Saves a text file to the user's computer. Website only for now (admin
/// CSV export); [isSupported] is false in the phone apps.
abstract interface class FileDownloader {
  bool get isSupported;

  void saveText(String fileName, String content, {String mimeType});
}

@Riverpod(keepAlive: true)
FileDownloader fileDownloader(Ref ref) => createFileDownloader();
