import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/services/photo_picker.dart';
import '../../../data/repositories/avatar_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../auth/data/auth_repository.dart';

part 'account_controllers.g.dart';

/// Profile photo: pick → upload to Storage → save URL on the profile.
/// State value = a message for a snackbar (null = nothing to show).
@riverpod
class AvatarController extends _$AvatarController {
  @override
  FutureOr<String?> build() => null;

  Future<void> change(String uid, PhotoSource source) async {
    final picker = ref.read(photoPickerProvider);
    final avatars = ref.read(avatarRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    final reporter = ref.read(errorReporterProvider);

    final photo = await picker.pick(source);
    if (photo == null || !ref.mounted) return; // cancelled
    if (photo.bytes.length >= AvatarRepository.maxBytes) {
      state = const AsyncData(AppStrings.photoTooLarge);
      return;
    }

    state = const AsyncLoading();
    try {
      final url = await avatars.upload(
        uid,
        photo.bytes,
        contentType: photo.contentType,
      );
      await users.updateProfile(uid, photoUrl: url);
      if (ref.mounted) state = const AsyncData(AppStrings.photoUpdated);
    } on Object catch (e, st) {
      reporter.recordError(e, st);
      if (ref.mounted) state = const AsyncData(AppStrings.photoFailed);
    }
  }

  Future<void> remove(String uid) async {
    final avatars = ref.read(avatarRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    final reporter = ref.read(errorReporterProvider);

    state = const AsyncLoading();
    try {
      await users.removePhoto(uid);
      await avatars.delete(uid);
      if (ref.mounted) state = const AsyncData(AppStrings.photoRemoved);
    } on Object catch (e, st) {
      reporter.recordError(e, st);
      if (ref.mounted) state = const AsyncData(AppStrings.photoFailed);
    }
  }
}

/// Change password. State: AsyncData(false) idle, AsyncData(true) done.
@riverpod
class ChangePasswordController extends _$ChangePasswordController {
  @override
  FutureOr<bool> build() => false;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    });
    if (ref.mounted) state = result;
  }
}

/// Delete account: re-confirm identity, then delete on the server.
/// State: AsyncData(false) idle, AsyncData(true) deleted.
@riverpod
class DeleteAccountController extends _$DeleteAccountController {
  @override
  FutureOr<bool> build() => false;

  /// [onDeleted] is called after success. It runs here (not in the UI)
  /// because signing out makes the router leave the screen straight away.
  Future<void> submit({String? password, VoidCallback? onDeleted}) async {
    final auth = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await auth.reauthenticate(password: password);
      await auth.deleteAccount();
      return true;
    });
    if (result.value == true) onDeleted?.call();
    if (ref.mounted) state = result;
  }
}
