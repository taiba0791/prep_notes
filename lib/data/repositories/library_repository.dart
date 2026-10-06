import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/recently_viewed.dart';

part 'library_repository.g.dart';

/// A student's own things: purchases (read-only) and recently viewed notes.
abstract interface class LibraryRepository {
  static const recentlyViewedLimit = 20;

  /// True if `users/{uid}/entitlements/{noteId}` exists. Entitlements are
  /// written ONLY by Cloud Functions after payment (Phase 4).
  Future<bool> ownsNote(String uid, String noteId);

  /// Remembers that [uid] opened a note; keeps only the newest 20.
  Future<void> recordView(String uid, RecentlyViewed item);

  /// Newest first (max 20).
  Future<List<RecentlyViewed>> recentlyViewed(String uid);
}

class FirestoreLibraryRepository implements LibraryRepository {
  FirestoreLibraryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _recent(String uid) =>
      _db.collection(FirestorePaths.recentlyViewed(uid));

  @override
  Future<bool> ownsNote(String uid, String noteId) async =>
      (await _db.doc(FirestorePaths.entitlement(uid, noteId)).get()).exists;

  @override
  Future<void> recordView(String uid, RecentlyViewed item) async {
    final data = item.toJson()
      ..[RecentlyViewedFields.viewedAt] = FieldValue.serverTimestamp();
    await _recent(uid).doc(item.noteId).set(data);

    // Trim to the newest 20 (the list is tiny, so this read is cheap).
    final extra = await _recent(uid)
        .orderBy(RecentlyViewedFields.viewedAt, descending: true)
        .limit(LibraryRepository.recentlyViewedLimit + 10)
        .get();
    for (final d in extra.docs.skip(LibraryRepository.recentlyViewedLimit)) {
      await d.reference.delete();
    }
  }

  @override
  Future<List<RecentlyViewed>> recentlyViewed(String uid) async {
    final snap = await _recent(uid)
        .orderBy(RecentlyViewedFields.viewedAt, descending: true)
        .limit(LibraryRepository.recentlyViewedLimit)
        .get();
    return [for (final d in snap.docs) RecentlyViewed.fromJson(d.data())];
  }
}

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) =>
    FirestoreLibraryRepository(ref.watch(firestoreProvider));
