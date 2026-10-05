import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/repositories/user_repository.dart';
import '../../auth/data/auth_repository.dart';

part 'profile_controllers.g.dart';

/// Saves the Edit Profile form. State: AsyncData(false) idle, AsyncLoading,
/// AsyncData(true) saved, AsyncError on failure.
@riverpod
class EditProfileController extends _$EditProfileController {
  @override
  FutureOr<bool> build() => false;

  Future<void> save({
    required String uid,
    required String name,
    String? universityId,
    int? semester,
  }) async {
    final users = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await users.updateProfile(
        uid,
        name: name,
        universityId: universityId,
        semester: semester,
      );
      return true;
    });
    if (ref.mounted) state = result;
  }
}

/// Email-verification banner actions. State value = a message to show in a
/// snackbar after the action (or null for none).
@riverpod
class EmailVerificationController extends _$EmailVerificationController {
  @override
  FutureOr<String?> build() => null;

  Future<void> resend() => _run(
    (auth) => auth.sendEmailVerification(),
    message: AppStrings.verifyEmailSent,
  );

  /// After clicking the link in the email: re-read the account so the banner
  /// disappears.
  Future<void> checkAgain() => _run((auth) => auth.refreshSession());

  Future<void> _run(
    Future<void> Function(AuthRepository) action, {
    String? message,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await action(auth);
      return message;
    });
    if (ref.mounted) state = result;
  }
}
