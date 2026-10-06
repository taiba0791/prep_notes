import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/note.dart';
import '../models/note_query.dart';
import 'note_repository.dart';

part 'browse_repository.g.dart';

/// Real catalog totals for the Home stats band.
typedef CatalogCounts = ({int notes, int universities, int subjects});

/// What students can read: PUBLISHED notes only (every query filters on
/// `isPublished == true`, which firestore.rules requires).
abstract interface class BrowseRepository {
  static const pageSize = 12;

  /// Filtered, sorted, paginated (limit + startAfter).
  Future<NotePage> notes(NoteQuery query, {Object? cursor});

  /// "Popular this week": admin-featured notes first, then most purchased.
  Future<List<Note>> popular({int limit = 4});

  /// Other notes from the same subject.
  Future<List<Note>> related(Note note, {int limit = 4});

  /// Keyword search (see buildSearchKeywords). Not full-text: every word must
  /// be the start of a word in the title / subject / university / module /
  /// tags. Phase 9 can swap this for Algolia or Typesense.
  Future<List<Note>> search(String text, {int limit = 30});

  /// A published note, or null if it doesn't exist or isn't published.
  Future<Note?> note(String id);

  /// URL of the free-preview PDF (first N pages), or null if none.
  Future<String?> previewUrl(String noteId);

  /// The free-preview PDF itself (phones show it in-app). Max 20 MB.
  Future<Uint8List?> previewBytes(String noteId);

  /// Counted on the server (cheap aggregate queries, no documents read).
  Future<CatalogCounts> counts();
}

class FirestoreBrowseRepository implements BrowseRepository {
  /// Storage is only needed for previews, so it's looked up lazily.
  FirestoreBrowseRepository(
    this._db, {
    required FirebaseStorage Function() storage,
  }) : _storageOf = storage;

  final FirebaseFirestore _db;
  final FirebaseStorage Function() _storageOf;

  FirebaseStorage get _storage => _storageOf();

  Query<Map<String, dynamic>> get _published => _db
      .collection(FirestoreCollections.notes)
      .where(NoteFields.isPublished, isEqualTo: true);

  Note _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      Note.fromJson(d.data()!).copyWith(id: d.id);

  @override
  Future<NotePage> notes(NoteQuery query, {Object? cursor}) async {
    var q = _published;

    // Where in the catalog (the most specific level is enough).
    if (query.moduleId != null) {
      q = q.where(NoteFields.moduleId, isEqualTo: query.moduleId);
    } else if (query.subjectId != null) {
      q = q.where(NoteFields.subjectId, isEqualTo: query.subjectId);
    } else if (query.semesterId != null) {
      q = q.where(NoteFields.semesterId, isEqualTo: query.semesterId);
    } else if (query.universityId != null) {
      q = q.where(NoteFields.universityId, isEqualTo: query.universityId);
    }

    // Free = price 0 (free notes are always saved with price 0).
    if (query.priceFilter == PriceFilter.free) {
      q = q.where(NoteFields.price, isEqualTo: 0);
    } else {
      final min = query.priceFilter == PriceFilter.paid
          ? ((query.minPrice ?? 1) < 1 ? 1 : (query.minPrice ?? 1))
          : query.minPrice;
      if (min != null) {
        q = q.where(NoteFields.price, isGreaterThanOrEqualTo: min);
      }
      if (query.maxPrice != null) {
        q = q.where(NoteFields.price, isLessThanOrEqualTo: query.maxPrice);
      }
    }

    q = switch (query.effectiveSort) {
      NoteSort.newest => q.orderBy(NoteFields.updatedAt, descending: true),
      NoteSort.popular => q.orderBy(NoteFields.purchaseCount, descending: true),
      NoteSort.priceLow => q.orderBy(NoteFields.price),
      NoteSort.priceHigh => q.orderBy(NoteFields.price, descending: true),
    };

    q = q.limit(BrowseRepository.pageSize + 1); // +1 tells us if there's more
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);

    final snap = await q.get();
    final docs = snap.docs.take(BrowseRepository.pageSize).toList();
    return NotePage(
      [for (final d in docs) _fromDoc(d)],
      docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > BrowseRepository.pageSize,
    );
  }

  @override
  Future<List<Note>> popular({int limit = 4}) async {
    final featured = await _published
        .where(NoteFields.isFeatured, isEqualTo: true)
        .orderBy(NoteFields.updatedAt, descending: true)
        .limit(limit)
        .get();
    final result = [for (final d in featured.docs) _fromDoc(d)];
    if (result.length >= limit) return result;

    final mostBought = await _published
        .orderBy(NoteFields.purchaseCount, descending: true)
        .limit(limit * 2)
        .get();
    for (final d in mostBought.docs) {
      if (result.length >= limit) break;
      if (result.every((n) => n.id != d.id)) result.add(_fromDoc(d));
    }
    return result;
  }

  @override
  Future<List<Note>> related(Note note, {int limit = 4}) async {
    final snap = await _published
        .where(NoteFields.subjectId, isEqualTo: note.subjectId)
        .orderBy(NoteFields.updatedAt, descending: true)
        .limit(limit + 1)
        .get();
    return [
      for (final d in snap.docs)
        if (d.id != note.id) _fromDoc(d),
    ].take(limit).toList();
  }

  /// Lower-case words, same splitting as buildSearchKeywords (max 20 chars).
  static List<String> searchTokens(String text) => [
    for (final w in text.toLowerCase().split(RegExp(r'[^a-z0-9+#]+')))
      if (w.isNotEmpty) w.length > 20 ? w.substring(0, 20) : w,
  ];

  @override
  Future<List<Note>> search(String text, {int limit = 30}) async {
    final tokens = searchTokens(text);
    if (tokens.isEmpty) return const [];
    // Firestore allows one array-contains per query: use the longest word
    // (usually the most specific), then check the rest here.
    final longest = tokens.reduce((a, b) => b.length > a.length ? b : a);
    final snap = await _published
        .where(NoteFields.searchKeywords, arrayContains: longest)
        .orderBy(NoteFields.updatedAt, descending: true)
        .limit(limit * 2)
        .get();
    return [
      for (final d in snap.docs)
        if (tokens.every((t) => _fromDoc(d).searchKeywords.contains(t)))
          _fromDoc(d),
    ].take(limit).toList();
  }

  @override
  Future<Note?> note(String id) async {
    try {
      final snap = await _db.doc(FirestorePaths.note(id)).get();
      if (!snap.exists) return null;
      final note = _fromDoc(snap);
      return note.isPublished ? note : null;
    } on FirebaseException catch (e) {
      // Unpublished notes are hidden by the rules → treat as "not found".
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<String?> previewUrl(String noteId) async {
    try {
      return await _storage
          .ref(StoragePaths.notePreview(noteId))
          .getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List?> previewBytes(String noteId) async {
    try {
      return await _storage
          .ref(StoragePaths.notePreview(noteId))
          .getData(20 * 1024 * 1024);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  @override
  Future<CatalogCounts> counts() async {
    final results = await Future.wait([
      _published.count().get(),
      _db
          .collection(FirestoreCollections.universities)
          .where(UniversityFields.isActive, isEqualTo: true)
          .count()
          .get(),
      _db
          .collection(FirestoreCollections.subjects)
          .where(SubjectFields.isActive, isEqualTo: true)
          .count()
          .get(),
    ]);
    return (
      notes: results[0].count ?? 0,
      universities: results[1].count ?? 0,
      subjects: results[2].count ?? 0,
    );
  }
}

@Riverpod(keepAlive: true)
BrowseRepository browseRepository(Ref ref) => FirestoreBrowseRepository(
  ref.watch(firestoreProvider),
  storage: () => ref.read(firebaseStorageProvider),
);
