import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/data/current_user_providers.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;
  late ProviderContainer container;

  Future<void> start({
    required AuthSession session,
    required String role,
  }) async {
    auth = FakeAuthRepository(session);
    db = FakeFirebaseFirestore();
    await db.doc(FirestorePaths.user('u1')).set({
      UserFields.name: 'Taiba',
      UserFields.email: 'taiba@x.com',
      UserFields.role: role,
    });
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(FirestoreUserRepository(db)),
      ],
    );
    addTearDown(container.dispose);
    // Listen (not read): Riverpod 3 pauses providers nobody listens to.
    container.listen(adminClaimSyncProvider, (_, _) {});
    await pumpEventQueue();
  }

  test('server made me admin → app refreshes its token', () async {
    await start(
      session: const AuthSession(uid: 'u1'),
      role: UserRole.admin,
    );
    expect(auth.calls, contains('refresh'));
  });

  test('admin removed on the server → app refreshes too', () async {
    await start(
      session: const AuthSession(uid: 'u1', isAdmin: true),
      role: UserRole.student,
    );
    expect(auth.calls, contains('refresh'));
  });

  test('role and token agree → nothing to do', () async {
    await start(
      session: const AuthSession(uid: 'u1'),
      role: UserRole.student,
    );
    expect(auth.calls, isNot(contains('refresh')));
  });

  test('refreshes only once per change (no loops)', () async {
    await start(
      session: const AuthSession(uid: 'u1'),
      role: UserRole.admin,
    );
    await db.doc(FirestorePaths.user('u1')).update({UserFields.name: 'T'});
    await pumpEventQueue();
    expect(auth.calls.where((c) => c == 'refresh'), hasLength(1));
  });
}
