import 'file_download.dart';

FileDownloader createFileDownloader() => const _NoDownloads();

class _NoDownloads implements FileDownloader {
  const _NoDownloads();

  @override
  bool get isSupported => false;

  @override
  void saveText(
    String fileName,
    String content, {
    String mimeType = 'text/plain',
  }) => throw UnsupportedError('Downloads work on the website only.');
}
