import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/access.dart';
import '../search_keywords.dart';
import 'purchases_repository.dart';

part 'room_repository.g.dart';

/// Why an upload or link was refused (shown to the student).
enum RoomError { notOpen, badLink, tooBig, quotaFull, badType, failed }

class RoomException implements Exception {
  const RoomException(this.error);

  final RoomError error;

  @override
  String toString() => 'RoomException(${error.name})';
}

/// The student's private Resource Room. Firestore + Storage rules only allow
/// this while their Room is open (active bundle or subscription).
abstract interface class RoomRepository {
  static const pageSize = 20;
  static const allowedTypes = {
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Newest first; [search] matches title words; [type] filters.
  Future<Paged<RoomItem>> items(
    String uid, {
    String search = '',
    String? type,
    Object? cursor,
  });

  Future<RoomItem?> item(String uid, String itemId);

  Future<RoomItem> addLink(
    String uid, {
    required String type,
    required String url,
    required String title,
  });

  /// Creates the item, then uploads the file (rules require that order).
  Future<RoomItem> addFile(
    String uid, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String title,
    void Function(double progress)? onProgress,
  });

  Future<void> rename(String uid, String itemId, String title);

  /// Deletes the item (a Cloud Function removes its file).
  Future<void> delete(String uid, String itemId);

  /// A link to an uploaded file (rules check Room access first).
  Future<String> fileUrl(RoomItem item);

  /// The uploaded file itself (phones show PDFs/photos in-app).
  Future<Uint8List> fileBytes(RoomItem item);
}

class FirebaseRoomRepository implements RoomRepository {
  FirebaseRoomRepository(
    this._db, {
    required FirebaseStorage Function() storage,
  }) : _storageOf = storage;

  final FirebaseFirestore _db;
  final FirebaseStorage Function() _storageOf;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(FirestorePaths.roomItems(uid));

  static RoomItem _item(DocumentSnapshot<Map<String, dynamic>> d) =>
      RoomItem.fromJson(d.data()!).copyWith(id: d.id);

  static List<String> _keywords(String title, String extra) =>
      buildSearchKeywords([title, extra], max: 100);

  @override
  Future<Paged<RoomItem>> items(
    String uid, {
    String search = '',
    String? type,
    Object? cursor,
  }) async {
    Query<Map<String, dynamic>> q = _col(uid);
    if (type != null) q = q.where(RoomItemFields.type, isEqualTo: type);
    final words = searchTokens(search);
    if (words.isNotEmpty) {
      q = q.where(RoomItemFields.searchKeywords, arrayContains: words.first);
    }
    q = q
        .orderBy(RoomItemFields.createdAt, descending: true)
        .limit(RoomRepository.pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    final items = [
      for (final d in snap.docs)
        // Firestore can match one word; check the rest here.
        if (words
            .skip(1)
            .every(
              (w) =>
                  (d.data()[RoomItemFields.searchKeywords] as List?)?.contains(
                    w,
                  ) ??
                  false,
            ))
          _item(d),
    ];
    return (
      items: items,
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == RoomRepository.pageSize,
    );
  }

  @override
  Future<RoomItem?> item(String uid, String itemId) async {
    final d = await _col(uid).doc(itemId).get();
    return d.exists ? _item(d) : null;
  }

  Future<RoomItem> _create(
    String uid,
    String id,
    Map<String, Object?> data,
  ) async {
    try {
      await _col(uid).doc(id).set({
        ...data,
        RoomItemFields.createdAt: FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw RoomException(
        e.code == 'permission-denied' ? RoomError.notOpen : RoomError.failed,
      );
    }
    return _item(await _col(uid).doc(id).get());
  }

  @override
  Future<RoomItem> addLink(
    String uid, {
    required String type,
    required String url,
    required String title,
  }) => _create(uid, _col(uid).doc().id, {
    RoomItemFields.type: type,
    RoomItemFields.title: title.trim(),
    RoomItemFields.url: url,
    RoomItemFields.searchKeywords: _keywords(title, type),
  });

  @override
  Future<RoomItem> addFile(
    String uid, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    if (!RoomRepository.allowedTypes.contains(contentType)) {
      throw const RoomException(RoomError.badType);
    }
    if (bytes.length > AccessRules.roomMaxFileBytes) {
      throw const RoomException(RoomError.tooBig);
    }
    // Storage rules allow only simple file names.
    final safeName = fileName
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final name = safeName.isEmpty ? 'file' : safeName;
    final id = _col(uid).doc().id;
    final path = StoragePaths.roomFile(uid, id, name);
    final item = await _create(uid, id, {
      RoomItemFields.type: RoomItemType.file,
      RoomItemFields.title: title.trim(),
      RoomItemFields.storagePath: path,
      RoomItemFields.fileName: name,
      RoomItemFields.contentType: contentType,
      RoomItemFields.sizeBytes: bytes.length,
      RoomItemFields.searchKeywords: _keywords(title, name),
    });
    try {
      final task = _storageOf()
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: contentType));
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(s.bytesTransferred / s.totalBytes);
        }
      });
      await task;
      await sub.cancel();
    } on FirebaseException {
      await _col(uid).doc(id).delete(); // don't leave an empty item behind
      throw const RoomException(RoomError.failed);
    }
    return item;
  }

  @override
  Future<void> rename(String uid, String itemId, String title) async {
    final item = await this.item(uid, itemId);
    await _col(uid).doc(itemId).update({
      RoomItemFields.title: title.trim(),
      RoomItemFields.searchKeywords: _keywords(
        title,
        item?.fileName ?? item?.type ?? '',
      ),
    });
  }

  @override
  Future<void> delete(String uid, String itemId) =>
      _col(uid).doc(itemId).delete();

  @override
  Future<String> fileUrl(RoomItem item) =>
      _storageOf().ref(item.storagePath!).getDownloadURL();

  @override
  Future<Uint8List> fileBytes(RoomItem item) async => (await _storageOf()
      .ref(item.storagePath!)
      .getData(AccessRules.roomMaxFileBytes))!;
}

@Riverpod(keepAlive: true)
RoomRepository roomRepository(Ref ref) => FirebaseRoomRepository(
  ref.watch(firestoreProvider),
  storage: () => ref.read(firebaseStorageProvider),
);
