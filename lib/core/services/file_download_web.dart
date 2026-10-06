import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'file_download.dart';

FileDownloader createFileDownloader() => const _BrowserDownloads();

/// Blob + a temporary `<a download>` link — the browser saves the file.
class _BrowserDownloads implements FileDownloader {
  const _BrowserDownloads();

  @override
  bool get isSupported => true;

  @override
  void saveText(
    String fileName,
    String content, {
    String mimeType = 'text/plain',
  }) {
    final blobCtor = globalContext['Blob']! as JSFunction;
    // A UTF-8 BOM so Excel shows ₹ and Indian names correctly.
    final parts = ['﻿$content'.toJS].toJS;
    final options = JSObject()..['type'] = '$mimeType;charset=utf-8'.toJS;
    final blob = blobCtor.callAsConstructor<JSObject>(parts, options);

    final url = globalContext['URL']! as JSObject;
    final href = url.callMethod<JSString>('createObjectURL'.toJS, blob);
    final document = globalContext['document']! as JSObject;
    final a = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS)
      ..['href'] = href
      ..['download'] = fileName.toJS;
    final body = document['body']! as JSObject;
    body.callMethod<JSAny?>('appendChild'.toJS, a);
    a.callMethod<JSAny?>('click'.toJS);
    body.callMethod<JSAny?>('removeChild'.toJS, a);
    url.callMethod<JSAny?>('revokeObjectURL'.toJS, href);
  }
}
