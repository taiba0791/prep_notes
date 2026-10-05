import '../../../core/constants/app_strings.dart';

/// Form validators. Each returns an error message, or null when valid.
/// Limits match firestore.rules (name 2–60) and Firebase Auth.
abstract final class Validators {
  static const minPasswordLength = 8;
  static const minNameLength = 2;
  static const maxNameLength = 60;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return AppStrings.validationEmailRequired;
    if (!_email.hasMatch(v)) return AppStrings.validationEmailInvalid;
    return null;
  }

  /// For login: only checks it's not empty (old accounts may be shorter).
  static String? passwordRequired(String? value) =>
      (value == null || value.isEmpty)
      ? AppStrings.validationPasswordRequired
      : null;

  /// For new passwords: at least 8 characters with a letter and a number.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return AppStrings.validationPasswordRequired;
    if (v.length < minPasswordLength) return AppStrings.validationPasswordShort;
    if (!v.contains(RegExp('[A-Za-z]')) || !v.contains(RegExp('[0-9]'))) {
      return AppStrings.validationPasswordWeak;
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String password) =>
      (value) =>
          value == password ? null : AppStrings.validationPasswordMismatch;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return AppStrings.validationNameRequired;
    if (v.length < minNameLength) return AppStrings.validationNameShort;
    if (v.length > maxNameLength) return AppStrings.validationNameLong;
    return null;
  }
}
