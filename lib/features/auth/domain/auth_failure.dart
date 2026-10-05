import '../../../core/constants/app_strings.dart';

/// Every way sign-in / sign-up / password actions can fail, as the user
/// should understand it. Screens show [message]; never raw Firebase errors.
enum AuthFailure {
  invalidCredential(AppStrings.authErrorInvalidCredential),
  emailAlreadyInUse(AppStrings.authErrorEmailInUse),
  weakPassword(AppStrings.authErrorWeakPassword),
  invalidEmail(AppStrings.authErrorInvalidEmail),
  userDisabled(AppStrings.authErrorUserDisabled),
  tooManyRequests(AppStrings.authErrorTooManyRequests),
  network(AppStrings.authErrorNetwork),
  requiresRecentLogin(AppStrings.authErrorRequiresRecentLogin),
  accountExistsWithDifferentCredential(AppStrings.authErrorAccountExists),
  providerDisabled(AppStrings.authErrorProviderDisabled),

  /// The user closed the Google popup / picker. Usually shown as nothing.
  cancelled(AppStrings.authErrorCancelled),
  unknown(AppStrings.authErrorUnknown);

  const AuthFailure(this.message);

  final String message;

  /// Maps a Firebase Auth error `code` (e.g. `wrong-password`) to a failure.
  static AuthFailure fromCode(String code) => switch (code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => invalidCredential,
    'email-already-in-use' => emailAlreadyInUse,
    'weak-password' => weakPassword,
    'invalid-email' || 'missing-email' => invalidEmail,
    'user-disabled' => userDisabled,
    'too-many-requests' => tooManyRequests,
    'network-request-failed' => network,
    'requires-recent-login' => requiresRecentLogin,
    'account-exists-with-different-credential' ||
    'credential-already-in-use' => accountExistsWithDifferentCredential,
    'operation-not-allowed' => providerDisabled,
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-cancelled' ||
    'canceled' ||
    'sign_in_canceled' => cancelled,
    _ => unknown,
  };
}

/// Thrown by the auth repository so callers handle one type of error.
class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}
