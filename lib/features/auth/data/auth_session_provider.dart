import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_session.dart';

part 'auth_session_provider.g.dart';

/// The current [AuthSession]. The router listens to this to run its guards.
///
/// Phase 0 placeholder: always starts as a guest. Phase 1 replaces this
/// with a Firebase Auth–backed implementation and removes [debugSignInAs].
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthSession build() => AuthSession.guest;

  /// DEBUG ONLY: pretend to sign in so guards and admin pages can be tried
  /// before real authentication exists. Does nothing in release builds.
  void debugSignInAs(AuthSession session) {
    if (kDebugMode) state = session;
  }

  void signOut() => state = AuthSession.guest;
}
