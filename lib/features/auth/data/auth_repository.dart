import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/firebase_config.dart';
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

  /// Web: Google popup. Android/iOS: native account picker.
  /// Throws [AuthException] with [AuthFailure.cancelled] if the user closes it.
  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Sends (or re-sends) the "verify your email" message.
  Future<void> sendEmailVerification();

  /// Re-reads the ID token from the server so a newly granted admin claim or
  /// a just-verified email shows up immediately.
  Future<void> refreshSession();

  /// Email/password accounts only. Firebase requires the current password
  /// to be confirmed first.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Proves it's really the user before a sensitive action: with their
  /// password (email accounts) or Google again (Google accounts).
  Future<void> reauthenticate({String? password});

  /// Permanently deletes the account (server-side; see deleteMyAccount).
  /// Call [reauthenticate] first. Signs out afterwards.
  Future<void> deleteAccount();
}

/// Returns a Google ID token from the native account picker (Android/iOS).
typedef GoogleIdTokenProvider = Future<String> Function();

/// Calls the `deleteMyAccount` Cloud Function.
typedef DeleteAccountCall = Future<void> Function();

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(
    this._auth, {
    GoogleIdTokenProvider? googleIdToken,
    DeleteAccountCall? deleteAccountCall,
  }) : _googleIdToken = googleIdToken ?? _nativeGoogleIdToken,
       _deleteAccountCall = deleteAccountCall ?? _callDeleteMyAccount;

  final FirebaseAuth _auth;
  final GoogleIdTokenProvider _googleIdToken;
  final DeleteAccountCall _deleteAccountCall;

  static const _passwordProvider = 'password';

  @override
  Stream<AuthSession> sessionChanges() =>
      _auth.idTokenChanges().asyncMap(_toSession);

  /// Uids whose token we've already force-refreshed during this app run.
  final _refreshedThisRun = <String>{};

  Future<AuthSession> _toSession(User? user) async {
    if (user == null) return AuthSession.guest;
    // Once per app start, fetch a fresh token from Google so recently
    // granted / removed admin rights apply without logging out.
    final forceRefresh = _refreshedThisRun.add(user.uid);
    final IdTokenResult token;
    try {
      token = await user.getIdTokenResult(forceRefresh);
    } on FirebaseAuthException {
      // Offline at start-up: fall back to the cached token.
      return _sessionFrom(user, await user.getIdTokenResult());
    }
    return _sessionFrom(user, token);
  }

  AuthSession _sessionFrom(User user, IdTokenResult token) {
    return AuthSession(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
      isAdmin: token.claims?['admin'] == true,
      hasPassword: user.providerData.any(
        (p) => p.providerId == _passwordProvider,
      ),
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
    return (
      uid: user.uid,
      email: user.email,
      displayName: name.trim(),
      photoUrl: null,
    );
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

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
    final UserCredential cred;
    if (kIsWeb) {
      cred = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      cred = await _auth.signInWithCredential(await _googleCredential());
    }
    return _toAuthUser(cred.user!);
  });

  Future<AuthCredential> _googleCredential() async =>
      GoogleAuthProvider.credential(idToken: await _googleIdToken());

  AuthUser _toAuthUser(User user) => (
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );

  @override
  Future<void> signOut() => _guard(() async {
    await _auth.signOut();
    // Forget the Google account too, so the picker shows next time.
    if (!kIsWeb && _googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object {
        // Not critical.
      }
    }
  });

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

  User get _signedInUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(AuthFailure.requiresRecentLogin);
    }
    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final user = _signedInUser;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email ?? '',
        password: currentPassword,
      ),
    );
    await user.updatePassword(newPassword);
  });

  @override
  Future<void> reauthenticate({String? password}) => _guard(() async {
    final user = _signedInUser;
    final usesPassword = user.providerData.any(
      (p) => p.providerId == _passwordProvider,
    );
    if (usesPassword && password != null) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email ?? '',
          password: password,
        ),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      await user.reauthenticateWithCredential(await _googleCredential());
    }
  });

  @override
  Future<void> deleteAccount() => _guard(() async {
    try {
      await _deleteAccountCall();
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(
        e.code == 'failed-precondition'
            ? AuthFailure.requiresRecentLogin
            : AuthFailure.fromCode(e.code),
      );
    }
    // The account no longer exists on the server; clear it locally.
    await signOut();
  });

  /// Runs [action] and converts Firebase / Google errors into [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(AuthFailure.fromCode(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(AuthFailure.fromCode(e.code));
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
    }
  }

  static Future<void>? _googleInit;

  /// Native Google sign-in (google_sign_in 7): initialise once, then show
  /// the account picker and return the ID token for Firebase.
  static Future<String> _nativeGoogleIdToken() async {
    _googleInit ??= GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? FirebaseConfig.googleIosClientId
          : null,
      serverClientId: FirebaseConfig.googleWebClientId,
    );
    await _googleInit;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException(AuthFailure.unknown);
    return idToken;
  }

  static Future<void> _callDeleteMyAccount() async {
    await FirebaseConfig.functions
        .httpsCallable('deleteMyAccount')
        .call<void>();
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final functions = ref.watch(functionsProvider);
  return FirebaseAuthRepository(
    ref.watch(firebaseAuthProvider),
    deleteAccountCall: () async {
      await functions.httpsCallable('deleteMyAccount').call<void>();
    },
  );
}

/// The live [AuthSession]. Loading until Firebase restores the session.
@Riverpod(keepAlive: true)
Stream<AuthSession> authSession(Ref ref) =>
    ref.watch(authRepositoryProvider).sessionChanges();
