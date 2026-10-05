import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_repository.dart';
import 'auth_repository.dart';

part 'current_user_providers.g.dart';

/// The signed-in user's `users/{uid}` profile, live. Null when signed out
/// (or while the profile is still being created).
@Riverpod(keepAlive: true)
Stream<UserProfile?> currentUserProfile(Ref ref) {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchProfile(uid);
}

/// Keeps the app's admin status in step with the server.
///
/// When a Cloud Function grants or removes admin, it also sets
/// `users/{uid}.role`. If that role disagrees with the claim in our current
/// login token, ask Google for a fresh token (once per role value).
/// The role field is only a hint — the token claim stays the source of truth.
@Riverpod(keepAlive: true)
void adminClaimSync(Ref ref) {
  String? lastRefreshedFor;
  ref.listen(currentUserProfileProvider, (_, next) async {
    final profile = next.value;
    final session = ref.read(authSessionProvider).value;
    if (profile == null || session == null || !session.isSignedIn) return;

    final roleSaysAdmin = profile.role == UserRole.admin;
    if (roleSaysAdmin == session.isAdmin) return;

    final key = '${profile.uid}:${profile.role}';
    if (lastRefreshedFor == key) return; // already tried for this change
    lastRefreshedFor = key;
    await ref.read(authRepositoryProvider).refreshSession();
  }, fireImmediately: true);
}
