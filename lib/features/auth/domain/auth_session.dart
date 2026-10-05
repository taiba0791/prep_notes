import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

/// Who is using the app right now, as far as the UI and routing care.
///
/// Built from Firebase Auth by the auth repository. `isAdmin` comes from the
/// `admin` custom claim in the ID token (set only by a Cloud Function).
/// Hiding pages is convenience — real protection is in rules and Functions.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    /// Firebase uid; null when signed out.
    String? uid,
    String? email,
    @Default(false) bool emailVerified,
    @Default(false) bool isAdmin,

    /// Signed up with email + password (can change password). False for
    /// Google-only accounts.
    @Default(false) bool hasPassword,

    /// True only while Firebase restores the session at app start.
    @Default(false) bool isLoading,
  }) = _AuthSession;

  const AuthSession._();

  static const guest = AuthSession();
  static const loading = AuthSession(isLoading: true);

  bool get isSignedIn => uid != null;
}

/// The account returned right after sign-in / sign-up.
/// `email` is Firebase's stored version (what security rules compare with).
typedef AuthUser = ({
  String uid,
  String? email,
  String? displayName,
  String? photoUrl,
});
