import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:material_ui/material_ui.dart';

/// Website: an `<iframe>` filling the space.
Widget buildEmbeddedPage(String url) => HtmlElementView.fromTagName(
  key: ValueKey(url),
  tagName: 'iframe',
  onElementCreated: (Object element) {
    final iframe = element as JSObject;
    iframe['src'] = url.toJS;
    iframe['allow'] = 'autoplay; fullscreen; encrypted-media'.toJS;
    iframe['allowFullscreen'] = true.toJS;
    final style = iframe['style']! as JSObject;
    style['border'] = 'none'.toJS;
    style['width'] = '100%'.toJS;
    style['height'] = '100%'.toJS;
  },
);
