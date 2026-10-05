import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../data/repositories/user_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

part 'auth_controllers.g.dart';

// Each controller's state is an AsyncValue<void>:
//   AsyncData  → idle / done
//   AsyncLoading → show a spinner, disable the button
//   AsyncError(AuthException) → show the friendly message
//
// On success the screens do NOT navigate: the router guards see the new
// session and send the user back to where they came from.
//
// Repositories are read BEFORE the first `await`: once sign-in succeeds the
// router leaves the screen, this controller is disposed, and `ref` can no
// longer be used.

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({required String email, required String password}) async {
    final auth = ref.read(authRepositoryProvider);
    final profiles = _ProfileHelper(ref);

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = await auth.signIn(email: email, password: password);
      unawaited(profiles.ensureProfile(user));
    });
    if (ref.mounted) state = result;
  }
}

@riverpod
class RegisterController extends _$RegisterController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required String name,
    required String email,
    required String password,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    final profiles = _ProfileHelper(ref);

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = await auth.register(
        name: name,
        email: email,
        password: password,
      );
      unawaited(profiles.ensureProfile(user, name: name));
      // Best effort: a failed email doesn't undo a successful sign-up; the
      // user can re-send it from their profile.
      unawaited(auth.sendEmailVerification().catchError(profiles.report));
    });
    if (ref.mounted) state = result;
  }
}

@riverpod
class ForgotPasswordController extends _$ForgotPasswordController {
  /// State value: true once the reset email was sent.
  @override
  FutureOr<bool> build() => false;

  Future<void> submit(String email) async {
    final auth = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await auth.sendPasswordReset(email);
      return true;
    });
    if (ref.mounted) state = result;
  }
}

/// Makes sure `users/{uid}` exists after sign-in / sign-up, and records the
/// last login. Never fails the sign-in itself — errors are reported instead,
/// and the next sign-in tries again.
class _ProfileHelper {
  _ProfileHelper(Ref ref)
    : _users = ref.read(userRepositoryProvider),
      _reporter = ref.read(errorReporterProvider);

  final UserRepository _users;
  final ErrorReporter _reporter;

  Future<void> ensureProfile(AuthUser user, {String? name}) async {
    try {
      final email = user.email ?? '';
      final created = await _users.createProfileIfMissing(
        uid: user.uid,
        name: name ?? user.displayName ?? email.split('@').first,
        email: email,
      );
      if (!created) await _users.touchLastLogin(user.uid);
    } on Object catch (e, st) {
      report(e, st);
    }
  }

  void report(Object error, [StackTrace? stack]) =>
      _reporter.recordError(error, stack);
}
