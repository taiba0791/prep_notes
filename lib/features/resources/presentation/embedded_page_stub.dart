import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android / iOS: an in-app WebView.
Widget buildEmbeddedPage(String url) => _WebViewPage(url: url);

class _WebViewPage extends StatefulWidget {
  const _WebViewPage({required this.url});

  final String url;

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
