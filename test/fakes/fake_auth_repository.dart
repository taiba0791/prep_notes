import 'dart:async';

import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

/// In-memory [AuthRepository] for widget/router tests.
/// Call [emit] to change who is signed in.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthSession initial = AuthSession.guest])
    : _session = initial;

  final _controller = StreamController<AuthSession>.broadcast();
  AuthSession _session;
  final calls = <String>[];

  /// If set, the next action throws this (then it is cleared).
  Object? nextError;

  void _maybeThrow() {
    final e = nextError;
    nextError = null;
    if (e != null) throw e;
  }

  AuthSession get session => _session;

  void emit(AuthSession session) {
    _session = session;
    _controller.add(session);
  }

  @override
  Stream<AuthSession> sessionChanges() async* {
    yield _session;
    yield* _controller.stream;
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('register:$email');
    _maybeThrow();
    emit(AuthSession(uid: 'new-uid', email: email));
    return (uid: 'new-uid', email: email, displayName: name, photoUrl: null);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn:$email');
    _maybeThrow();
    emit(AuthSession(uid: 'uid-$email', email: email, emailVerified: true));
    return (uid: 'uid-$email', email: email, displayName: null, photoUrl: null);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    calls.add('google');
    _maybeThrow();
    emit(const AuthSession(uid: 'g-uid', email: 'g@gmail.com'));
    return (
      uid: 'g-uid',
      email: 'g@gmail.com',
      displayName: 'Google User',
      photoUrl: 'https://photo',
    );
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(AuthSession.guest);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    _maybeThrow();
  }

  @override
  Future<void> sendEmailVerification() async => calls.add('verify');

  @override
  Future<void> refreshSession() async => calls.add('refresh');

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add('changePassword:$currentPassword->$newPassword');
    _maybeThrow();
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    calls.add('reauth:${password ?? 'google'}');
    _maybeThrow();
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    _maybeThrow();
    emit(AuthSession.guest);
  }
}
