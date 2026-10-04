import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/errors/error_reporter.dart';
import 'firebase_options.dart';

/// App start-up, in order:
/// 1. Run everything inside an error zone, so no async error is lost.
/// 2. Connect to Firebase (project from `firebase_options.dart`).
/// 3. Route all uncaught errors to the [ErrorReporter]
///    (Crashlytics on Android/iOS, console on web).
/// 4. Start the app inside Riverpod's [ProviderScope].
void main() {
  // Used by the zone handler if an error happens before set-up finishes.
  ErrorReporter reporter = const ConsoleErrorReporter();

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Clean web URLs: /notes instead of /#/notes (no effect on mobile).
      usePathUrlStrategy();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      reporter = await ErrorReporter.create();

      // Errors inside Flutter widgets (build / layout / paint).
      FlutterError.onError = reporter.recordFlutterError;

      // Errors outside Flutter's callbacks (e.g. platform channels).
      PlatformDispatcher.instance.onError = (error, stack) {
        reporter.recordError(error, stack, fatal: true);
        return true;
      };

      runApp(
        ProviderScope(
          overrides: [errorReporterProvider.overrideWithValue(reporter)],
          child: const PrepNotesApp(),
        ),
      );
    },
    // Any other uncaught async error in this zone.
    (error, stack) => reporter.recordError(error, stack, fatal: true),
  );
}
