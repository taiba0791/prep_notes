import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'error_reporter.g.dart';

/// One place that receives every uncaught error in the app.
///
/// - Android / iOS: sends errors to Firebase Crashlytics (only in release /
///   profile builds, so development crashes don't pollute the dashboard).
/// - Web: Crashlytics isn't supported, so errors are logged to the console.
abstract interface class ErrorReporter {
  /// Picks the right implementation for the current platform.
  static Future<ErrorReporter> create() async {
    if (kIsWeb) return const ConsoleErrorReporter();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    return CrashlyticsErrorReporter(crashlytics);
  }

  /// Errors thrown while building, laying out or painting widgets.
  void recordFlutterError(FlutterErrorDetails details);

  /// Any other error (async code, callbacks, platform channels…).
  void recordError(Object error, StackTrace? stack, {bool fatal = false});
}

class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    // Still show the red error screen / console output while developing.
    FlutterError.presentError(details);
    _crashlytics.recordFlutterFatalError(details);
  }

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    _logToConsole(error, stack);
    _crashlytics.recordError(error, stack, fatal: fatal);
  }
}

class ConsoleErrorReporter implements ErrorReporter {
  const ConsoleErrorReporter();

  @override
  void recordFlutterError(FlutterErrorDetails details) =>
      FlutterError.presentError(details);

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) =>
      _logToConsole(error, stack);
}

void _logToConsole(Object error, StackTrace? stack) {
  developer.log(
    'Uncaught error',
    name: 'PrepNotes',
    error: error,
    stackTrace: stack,
  );
}

/// Lets any part of the app report a caught error:
/// `ref.read(errorReporterProvider).recordError(e, st)`.
///
/// The real instance is created in `main()` and supplied with
/// `errorReporterProvider.overrideWithValue(...)`.
@Riverpod(keepAlive: true)
ErrorReporter errorReporter(Ref ref) => const ConsoleErrorReporter();
