import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_failure.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

void main() {
  group('sessionChanges', () {
    test('signed out → guest', () async {
      final repo = FirebaseAuthRepository(MockFirebaseAuth());
      expect(await repo.sessionChanges().first, AuthSession.guest);
    });

    test('signed-in student', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 's1', email: 's@x.com', isEmailVerified: false),
      );
      final session = await FirebaseAuthRepository(auth).sessionChanges().first;
      expect(session.uid, 's1');
      expect(session.isSignedIn, isTrue);
      expect(session.isAdmin, isFalse);
      expect(session.emailVerified, isFalse);
    });

    test('admin comes from the ID-token custom claim', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'a1', customClaim: {'admin': true}),
      );
      final session = await FirebaseAuthRepository(auth).sessionChanges().first;
      expect(session.isAdmin, isTrue);
    });

    test('a claim that is not exactly true is not admin', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'x', customClaim: {'admin': 'true'}),
      );
      final session = await FirebaseAuthRepository(auth).sessionChanges().first;
      expect(session.isAdmin, isFalse);
    });
  });

  test('register creates the account and sets the display name', () async {
    final auth = MockFirebaseAuth();
    final user = await FirebaseAuthRepository(auth).register(
      name: '  Taiba Shaikh ',
      email: ' taiba@x.com ',
      password: 'secret123',
    );
    expect(user.uid, isNotEmpty);
    expect(user.displayName, 'Taiba Shaikh');
    expect(auth.currentUser!.displayName, 'Taiba Shaikh');
  });

  test('signIn turns Firebase errors into a friendly AuthFailure', () async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await expectLater(
      () =>
          FirebaseAuthRepository(auth)
              .signIn(email: 'a@b.com', password: 'nope'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.failure,
          'failure',
          AuthFailure.invalidCredential,
        ),
      ),
    );
  });

  test('register maps email-already-in-use', () async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await expectLater(
      () =>
          FirebaseAuthRepository(auth)
              .register(name: 'A', email: 'a@b.com', password: 'secret123'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.failure,
          'failure',
          AuthFailure.emailAlreadyInUse,
        ),
      ),
    );
  });

  test('signOut signs the user out', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u'));
    await FirebaseAuthRepository(auth).signOut();
    expect(auth.currentUser, isNull);
  });
}
