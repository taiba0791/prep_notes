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
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('register:$email');
    emit(AuthSession(uid: 'new-uid', email: email));
    return 'new-uid';
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    emit(AuthSession(uid: 'uid-$email', email: email, emailVerified: true));
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(AuthSession.guest);
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset:$email');

  @override
  Future<void> sendEmailVerification() async => calls.add('verify');

  @override
  Future<void> refreshSession() async => calls.add('refresh');
}
