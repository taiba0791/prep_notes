import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

// Firebase init, error zone and Crashlytics are added in Step 0.8.
void main() {
  // Clean web URLs: /notes instead of /#/notes (no effect on mobile).
  usePathUrlStrategy();
  runApp(const ProviderScope(child: PrepNotesApp()));
}
