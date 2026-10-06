import '../../../core/constants/app_strings.dart';

/// Why a checkout / file request didn't work, in words a student understands.
enum PurchaseFailure {
  signIn(AppStrings.payErrSignIn),
  alreadyOwned(AppStrings.payErrAlreadyOwned),
  notAvailable(AppStrings.payErrNotAvailable),
  notPurchased(AppStrings.payErrNotPurchased),
  notVerified(AppStrings.payErrNotVerified),
  tooMany(AppStrings.payErrTooMany),
  busy(AppStrings.payErrBusy),
  network(AppStrings.payErrNetwork),
  unknown(AppStrings.payErrUnknown);

  const PurchaseFailure(this.message);

  final String message;

  /// Maps a Cloud Functions error code (+ message) to a failure.
  static PurchaseFailure fromCode(String code, [String? message]) =>
      switch (code) {
        'unauthenticated' => signIn,
        'already-exists' => alreadyOwned,
        'not-found' => notAvailable,
        'failed-precondition' => notAvailable,
        'permission-denied' =>
          message == 'not-purchased' ? notPurchased : notVerified,
        'resource-exhausted' => tooMany,
        'unavailable' || 'deadline-exceeded' => busy,
        _ => unknown,
      };
}

/// Thrown by PurchasesRepository.
class PurchaseException implements Exception {
  const PurchaseException(this.failure);

  final PurchaseFailure failure;

  @override
  String toString() => 'PurchaseException(${failure.name})';
}
