import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/note.dart';

part 'note_repository.g.dart';

/// One page of results plus where to continue from.
class NotePage {
  const NotePage(this.notes, this.cursor, {required this.hasMore});

  final List<Note> notes;

  /// Pass to the next `list(...)` call to continue (opaque to callers).
  final Object? cursor;
  final bool hasMore;
}

/// Filters for the admin notes list (most specific one wins).
class NoteFilter {
  const NoteFilter({
    this.universityId,
    this.semesterId,
    this.subjectId,
    this.moduleId,
  });

  final String? universityId;
  final String? semesterId;
  final String? subjectId;
  final String? moduleId;

  @override
  bool operator ==(Object other) =>
      other is NoteFilter &&
      other.universityId == universityId &&
      other.semesterId == semesterId &&
      other.subjectId == subjectId &&
      other.moduleId == moduleId;

  @override
  int get hashCode =>
      Object.hash(universityId, semesterId, subjectId, moduleId);
}

/// Notes (admin side in Phase 2; student browsing in Phase 3).
abstract interface class NoteRepository {
  static const pageSize = 20;

  /// A fresh id, so files can be uploaded under it before saving.
  String newNoteId();

  Future<Note?> get(String id);

  /// Newest first, paginated (limit + startAfter).
  Future<NotePage> listForAdmin({NoteFilter filter, Object? cursor});

  /// Creates the document if new, otherwise updates the editable fields.
  /// Never writes the Function-owned fields (page count, size, preview,
  /// purchase count).
  Future<void> save(Note note, {required bool isNew});

  /// Deletes the document; a Cloud Function then deletes its files.
  Future<void> delete(String id);
}

/// Uploads for catalog files (admin only — see storage.rules).
abstract interface class CatalogFilesRepository {
  /// 50 MB, matching storage.rules.
  static const maxPdfBytes = 50 * 1024 * 1024;

  /// 2 MB, matching storage.rules.
  static const maxImageBytes = 2 * 1024 * 1024;

  /// Uploads the private PDF and returns its Storage path.
  Future<String> uploadNotePdf(
    String noteId,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  });

  /// Uploads the public thumbnail and returns its URL.
  Future<String> uploadNoteThumbnail(
    String noteId,
    Uint8List bytes,
    String contentType,
  );

  /// Uploads a university logo and returns its URL.
  Future<String> uploadUniversityLogo(
    String universityId,
    Uint8List bytes,
    String contentType,
  );
}

class FirestoreNoteRepository implements NoteRepository {
  FirestoreNoteRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection(FirestoreCollections.notes);

  Note _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      Note.fromJson(d.data()!).copyWith(id: d.id);

  @override
  String newNoteId() => _notes.doc().id;

  @override
  Future<Note?> get(String id) async {
    final snap = await _notes.doc(id).get();
    return snap.exists ? _fromDoc(snap) : null;
  }

  @override
  Future<NotePage> listForAdmin({
    NoteFilter filter = const NoteFilter(),
    Object? cursor,
  }) async {
    Query<Map<String, dynamic>> q = _notes;
    if (filter.moduleId != null) {
      q = q.where(NoteFields.moduleId, isEqualTo: filter.moduleId);
    } else if (filter.subjectId != null) {
      q = q.where(NoteFields.subjectId, isEqualTo: filter.subjectId);
    } else if (filter.semesterId != null) {
      q = q.where(NoteFields.semesterId, isEqualTo: filter.semesterId);
    } else if (filter.universityId != null) {
      q = q.where(NoteFields.universityId, isEqualTo: filter.universityId);
    }
    q = q
        .orderBy(NoteFields.updatedAt, descending: true)
        .limit(NoteRepository.pageSize + 1); // +1 tells us if there's more
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);

    final snap = await q.get();
    final docs = snap.docs.take(NoteRepository.pageSize).toList();
    return NotePage(
      [for (final d in docs) _fromDoc(d)],
      docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > NoteRepository.pageSize,
    );
  }

  /// Fields only Cloud Functions may write.
  static const _functionOwned = [
    NoteFields.pageCount,
    NoteFields.fileSizeBytes,
    NoteFields.hasPreview,
    NoteFields.purchaseCount,
  ];

  @override
  Future<void> save(Note note, {required bool isNew}) async {
    final data = note.toJson()
      ..[NoteFields.updatedAt] = FieldValue.serverTimestamp();
    final ref = _notes.doc(note.id);
    if (isNew) {
      data
        ..[NoteFields.createdAt] = FieldValue.serverTimestamp()
        ..[NoteFields.pageCount] = 0
        ..[NoteFields.fileSizeBytes] = 0
        ..[NoteFields.hasPreview] = false
        ..[NoteFields.purchaseCount] = 0;
      await ref.set(data);
    } else {
      data
        ..remove(NoteFields.createdAt)
        ..removeWhere((k, _) => _functionOwned.contains(k));
      // Clear optional fields that were removed in the form.
      data.putIfAbsent(NoteFields.thumbnailUrl, FieldValue.delete);
      await ref.update(data);
    }
  }

  @override
  Future<void> delete(String id) => _notes.doc(id).delete();
}

class FirebaseCatalogFilesRepository implements CatalogFilesRepository {
  FirebaseCatalogFilesRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> uploadNotePdf(
    String noteId,
    Uint8List bytes, {
    void Function(double progress)? onProgress,
  }) async {
    final path = StoragePaths.notePdf(noteId);
    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    onProgress?.call(1);
    return path;
  }

  Future<String> _uploadPublic(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=86400',
      ),
    );
    final url = await ref.getDownloadURL();
    // Same file name on every upload → version it so caches refresh.
    return '$url&v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> uploadNoteThumbnail(
    String noteId,
    Uint8List bytes,
    String contentType,
  ) => _uploadPublic(StoragePaths.noteThumbnail(noteId), bytes, contentType);

  @override
  Future<String> uploadUniversityLogo(
    String universityId,
    Uint8List bytes,
    String contentType,
  ) => _uploadPublic(
    StoragePaths.universityLogo(universityId),
    bytes,
    contentType,
  );
}

@Riverpod(keepAlive: true)
NoteRepository noteRepository(Ref ref) =>
    FirestoreNoteRepository(ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
CatalogFilesRepository catalogFilesRepository(Ref ref) =>
    FirebaseCatalogFilesRepository(ref.watch(firebaseStorageProvider));
