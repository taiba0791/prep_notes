import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/user_profile.dart';

part 'user_repository.g.dart';

/// Reads and writes `users/{uid}` profile documents.
///
/// What a client may write is enforced by `firestore.rules` (e.g. `role` must
/// stay "student", `totalStudyMinutes` can't be changed by the client).
abstract interface class UserRepository {
  Future<UserProfile?> getProfile(String uid);

  /// Live updates of one profile (a single-document listener).
  Stream<UserProfile?> watchProfile(String uid);

  /// Creates the profile right after sign-up / first Google sign-in.
  /// Does nothing if it already exists. Returns true if it was created.
  Future<bool> createProfileIfMissing({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
  });

  /// Updates the fields a student may edit. Pass only what changed.
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? photoUrl,
    String? universityId,
    int? semester,
  });

  /// Records "last seen" after each sign-in.
  Future<void> touchLastLogin(String uid);

  /// Clears the profile photo field.
  Future<void> removePhoto(String uid);
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  UserProfile? _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return null;
    return UserProfile.fromJson(data).copyWith(uid: snap.id);
  }

  @override
  Future<UserProfile?> getProfile(String uid) async =>
      _fromSnapshot(await _doc(uid).get());

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _doc(uid).snapshots().map(_fromSnapshot);

  @override
  Future<bool> createProfileIfMissing({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    final ref = _doc(uid);
    if ((await ref.get()).exists) return false;

    final data = UserProfile(
      name: name.trim(),
      email: email.trim(),
      photoUrl: photoUrl,
    ).toJson();
    // Server clock, not the phone's (rules check createdAt == request.time).
    data[UserFields.createdAt] = FieldValue.serverTimestamp();
    data[UserFields.lastLoginAt] = FieldValue.serverTimestamp();
    await ref.set(data);
    return true;
  }

  @override
  Future<void> updateProfile(
    String uid, {
    String? name,
    String? photoUrl,
    String? universityId,
    int? semester,
  }) async {
    final changes = <String, Object?>{
      if (name != null) UserFields.name: name.trim(),
      UserFields.photoUrl: ?photoUrl,
      UserFields.universityId: ?universityId,
      UserFields.semester: ?semester,
    };
    if (changes.isEmpty) return;
    await _doc(uid).update(changes);
  }

  @override
  Future<void> touchLastLogin(String uid) =>
      _doc(uid).update({UserFields.lastLoginAt: FieldValue.serverTimestamp()});

  @override
  Future<void> removePhoto(String uid) =>
      _doc(uid).update({UserFields.photoUrl: FieldValue.delete()});
}

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) =>
    FirestoreUserRepository(ref.watch(firestoreProvider));
