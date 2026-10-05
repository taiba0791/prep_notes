import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Firebase settings shared by the app.
abstract final class FirebaseConfig {
  /// Region of our Cloud Functions (same as Firestore: Mumbai).
  static const functionsRegion = 'asia-south1';

  /// The Functions instance for our region. Use this, never
  /// `FirebaseFunctions.instance` (that points at us-central1).
  static FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: functionsRegion);

  /// OAuth "Web client" of the Firebase project (google-services.json,
  /// client_type 3). Native Google sign-in needs it so Firebase can verify
  /// the Google ID token. Public identifier — not a secret.
  static const googleWebClientId =
      '803279888682-7lk16to87f3rdr2ijpm7fp4lh9ip9s9c.apps.googleusercontent.com';

  /// iOS OAuth client (from `flutterfire configure`).
  static String? get googleIosClientId =>
      DefaultFirebaseOptions.ios.iosClientId;
}

/// Switch the app to the local Firebase Emulator Suite.
///
/// Turn on at launch:
///   flutter run -d chrome --dart-define=USE_EMULATORS=true
/// From a phone / Android emulator, also pass the PC's address:
///   --dart-define=EMULATOR_HOST=192.168.1.20   (phone on same Wi-Fi)
///   --dart-define=EMULATOR_HOST=10.0.2.2       (Android emulator)
///
/// Ignored in release builds, so it can never ship by accident.
/// Ports must match `firebase.json`.
abstract final class EmulatorConfig {
  static const _requested = bool.fromEnvironment('USE_EMULATORS');
  static const host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const authPort = 9099;
  static const firestorePort = 8080;
  static const storagePort = 9199;
  static const functionsPort = 5001;

  static bool get enabled => _requested && !kReleaseMode;

  /// Must run right after `Firebase.initializeApp` and before any other
  /// Firebase call.
  static Future<void> connect() async {
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseStorage.instance.useStorageEmulator(host, storagePort);
    FirebaseConfig.functions.useFunctionsEmulator(host, functionsPort);
  }
}
