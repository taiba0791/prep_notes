import 'package:material_ui/material_ui.dart';

import 'embedded_page_stub.dart'
    if (dart.library.js_interop) 'embedded_page_web.dart'
    as impl;

/// Shows a web page (Drive preview, YouTube playlist) inside PrepNotes:
/// an in-app WebView on phones, an `<iframe>` on the website.
class EmbeddedPage extends StatelessWidget {
  const EmbeddedPage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) => impl.buildEmbeddedPage(url);
}
