import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_failure.dart';

/// Minimal UserInfo for MockUser.providerData.
class _Provider implements UserInfo {
  _Provider(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Matcher _failure(AuthFailure f) =>
    throwsA(isA<AuthException>().having((e) => e.failure, 'failure', f));

void main() {
  MockUser emailUser() => MockUser(
    uid: 'u1',
    email: 'taiba@x.com',
    providerData: [_Provider('password')],
  );

  test('session knows whether the account has a password', () async {
    final withPassword = await FirebaseAuthRepository(
      MockFirebaseAuth(signedIn: true, mockUser: emailUser()),
    ).sessionChanges().first;
    expect(withPassword.hasPassword, isTrue);

    final googleOnly = await FirebaseAuthRepository(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'g', providerData: [_Provider('google.com')]),
      ),
    ).sessionChanges().first;
    expect(googleOnly.hasPassword, isFalse);
  });

  test('changePassword re-authenticates then updates', () async {
    final user = emailUser();
    final repo = FirebaseAuthRepository(
      MockFirebaseAuth(signedIn: true, mockUser: user),
    );
    await repo.changePassword(
      currentPassword: 'old1234',
      newPassword: 'notes2027',
    );
  });

  test(
    'changePassword with a wrong current password → friendly error',
    () async {
      final user = emailUser();
      whenCalling(Invocation.method(#reauthenticateWithCredential, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final repo = FirebaseAuthRepository(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      );
      await expectLater(
        repo.changePassword(currentPassword: 'x', newPassword: 'notes2027'),
        _failure(AuthFailure.invalidCredential),
      );
    },
  );

  test('deleteAccount calls the server, then signs out', () async {
    var called = false;
    final auth = MockFirebaseAuth(signedIn: true, mockUser: emailUser());
    final repo = FirebaseAuthRepository(
      auth,
      deleteAccountCall: () async => called = true,
    );
    await repo.deleteAccount();
    expect(called, isTrue);
    expect(auth.currentUser, isNull);
  });

  test('server says "sign in again" → requiresRecentLogin', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: emailUser());
    final repo = FirebaseAuthRepository(
      auth,
      deleteAccountCall: () async => throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'requires-recent-login',
      ),
    );
    await expectLater(
      repo.deleteAccount(),
      _failure(AuthFailure.requiresRecentLogin),
    );
    expect(auth.currentUser, isNotNull, reason: 'still signed in');
  });
}
