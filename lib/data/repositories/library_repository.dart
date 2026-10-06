import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/access.dart';
import '../models/purchase.dart';
import '../models/recently_viewed.dart';

part 'library_repository.g.dart';

/// A student's own things: purchases (read-only) and recently viewed notes.
abstract interface class LibraryRepository {
  static const recentlyViewedLimit = 20;

  /// Can [uid] read the note right now? Own purchase (6 months) or an
  /// active bundle for its semester. Both are written ONLY by Cloud
  /// Functions after payment; the server checks again before any PDF.
  Future<NoteAccess> noteAccess(
    String uid,
    String noteId, {
    required String semesterId,
    DateTime? now,
  });

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
  Future<NoteAccess> noteAccess(
    String uid,
    String noteId, {
    required String semesterId,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final ent = await _db.doc(FirestorePaths.entitlement(uid, noteId)).get();
    if (ent.exists) {
      final p = Purchase.fromJson({...ent.data()!, 'noteId': noteId});
      if (p.isActiveAt(at)) {
        return NoteAccess(NoteAccessKind.owner, until: p.expiresAt);
      }
    }
    if (semesterId.isEmpty) return NoteAccess.none;
    final b = await _db.doc(FirestorePaths.bundle(uid, semesterId)).get();
    if (b.exists) {
      final bundle = SemesterBundle.fromJson({
        ...b.data()!,
        BundleFields.semesterId: semesterId,
      });
      if (bundle.isActiveAt(at)) {
        return NoteAccess(NoteAccessKind.bundle, until: bundle.expiresAt);
      }
    }
    return NoteAccess.none;
  }

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
