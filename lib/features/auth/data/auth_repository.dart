import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_session.dart';

part 'auth_repository.g.dart';

/// Everything the app can do with sign-in. Every method throws only
/// [AuthException] (with a friendly [AuthFailure]) on failure.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out and token refresh (e.g. new admin claim).
  Stream<AuthSession> sessionChanges();

  /// Creates the account and sets its display name.
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthUser> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Sends (or re-sends) the "verify your email" message.
  Future<void> sendEmailVerification();

  /// Re-reads the ID token from the server so a newly granted admin claim or
  /// a just-verified email shows up immediately.
  Future<void> refreshSession();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AuthSession> sessionChanges() =>
      _auth.idTokenChanges().asyncMap(_toSession);

  Future<AuthSession> _toSession(User? user) async {
    if (user == null) return AuthSession.guest;
    final token = await user.getIdTokenResult();
    return AuthSession(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      isAdmin: token.claims?['admin'] == true,
    );
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    return (uid: user.uid, email: user.email, displayName: name.trim());
  });

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toAuthUser(cred.user!);
      });

  AuthUser _toAuthUser(User user) =>
      (uid: user.uid, email: user.email, displayName: user.displayName);

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });

  @override
  Future<void> refreshSession() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload(); // picks up emailVerified
    await user.getIdToken(true); // picks up custom claims → idTokenChanges
  });

  /// Runs [action] and converts Firebase errors into [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(AuthFailure.fromCode(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(AuthFailure.fromCode(e.code));
    }
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(ref.watch(firebaseAuthProvider));

/// The live [AuthSession]. Loading until Firebase restores the session.
@Riverpod(keepAlive: true)
Stream<AuthSession> authSession(Ref ref) =>
    ref.watch(authRepositoryProvider).sessionChanges();
