import 'package:flutter/foundation.dart';

/// Who is using the app right now, as far as routing cares.
///
/// Phase 0 placeholder. In Phase 1 this is built from Firebase Auth
/// (signed-in user + `admin` custom claim from the ID token).
@immutable
class AuthSession {
  const AuthSession({required this.isSignedIn, required this.isAdmin});

  static const guest = AuthSession(isSignedIn: false, isAdmin: false);
  static const student = AuthSession(isSignedIn: true, isAdmin: false);
  static const admin = AuthSession(isSignedIn: true, isAdmin: true);

  final bool isSignedIn;
  final bool isAdmin;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.isSignedIn == isSignedIn &&
      other.isAdmin == isAdmin;

  @override
  int get hashCode => Object.hash(isSignedIn, isAdmin);
}
