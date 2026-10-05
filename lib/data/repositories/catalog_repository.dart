import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/catalog.dart';
import '../models/university.dart';

part 'catalog_repository.g.dart';

/// Thrown when deleting something that still has children
/// (e.g. a university that still has semesters).
class CatalogInUseException implements Exception {
  const CatalogInUseException(this.childCollection);

  /// e.g. [FirestoreCollections.semesters].
  final String childCollection;

  @override
  String toString() => 'CatalogInUseException($childCollection)';
}

/// Admin reads and writes for University → Semester → Subject → Module.
///
/// Lists under one parent are naturally small (a university has ≤ 12
/// semesters, a subject ≤ ~10 modules), so they load in one capped query.
/// Writes are admin-only (firestore.rules).
abstract interface class CatalogRepository {
  static const listLimit = 200;

  Future<List<University>> universities();
  Future<List<Semester>> semesters(String universityId);
  Future<List<Subject>> subjects(String semesterId);
  Future<List<Module>> modules(String subjectId);

  /// Creates (empty id) or updates. Returns the document id.
  Future<String> saveUniversity(University university);
  Future<String> saveSemester(Semester semester);
  Future<String> saveSubject(Subject subject);
  Future<String> saveModule(Module module);

  /// Turns an item on/off without deleting it.
  Future<void> setActive(String collection, String id, {required bool active});

  /// Deletes only if nothing points to it; otherwise throws
  /// [CatalogInUseException]. (Blocking is safer than cascading: one click
  /// can never wipe a whole university's notes.)
  Future<void> deleteUniversity(String id);
  Future<void> deleteSemester(String id);
  Future<void> deleteSubject(String id);
  Future<void> deleteModule(String id);
}

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  List<T> _map<T>(
    QuerySnapshot<Map<String, dynamic>> snap,
    T Function(Map<String, dynamic> json, String id) fromJson,
  ) => [for (final d in snap.docs) fromJson(d.data(), d.id)];

  @override
  Future<List<University>> universities() async {
    final snap = await _col(FirestoreCollections.universities)
        .orderBy(UniversityFields.order)
        .limit(CatalogRepository.listLimit)
        .get();
    return _map(snap, (j, id) => University.fromJson(j).copyWith(id: id));
  }

  @override
  Future<List<Semester>> semesters(String universityId) async {
    final snap = await _col(FirestoreCollections.semesters)
        .where(SemesterFields.universityId, isEqualTo: universityId)
        .orderBy(SemesterFields.number)
        .limit(CatalogRepository.listLimit)
        .get();
    return _map(snap, (j, id) => Semester.fromJson(j).copyWith(id: id));
  }

  @override
  Future<List<Subject>> subjects(String semesterId) async {
    final snap = await _col(FirestoreCollections.subjects)
        .where(SubjectFields.semesterId, isEqualTo: semesterId)
        .orderBy(SubjectFields.name)
        .limit(CatalogRepository.listLimit)
        .get();
    return _map(snap, (j, id) => Subject.fromJson(j).copyWith(id: id));
  }

  @override
  Future<List<Module>> modules(String subjectId) async {
    final snap = await _col(FirestoreCollections.modules)
        .where(ModuleFields.subjectId, isEqualTo: subjectId)
        .orderBy(ModuleFields.number)
        .limit(CatalogRepository.listLimit)
        .get();
    return _map(snap, (j, id) => Module.fromJson(j).copyWith(id: id));
  }

  Future<String> _save(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final ref = id.isEmpty ? _col(collection).doc() : _col(collection).doc(id);
    await ref.set(data);
    return ref.id;
  }

  @override
  Future<String> saveUniversity(University u) =>
      _save(FirestoreCollections.universities, u.id, u.toJson());

  @override
  Future<String> saveSemester(Semester s) =>
      _save(FirestoreCollections.semesters, s.id, s.toJson());

  @override
  Future<String> saveSubject(Subject s) =>
      _save(FirestoreCollections.subjects, s.id, s.toJson());

  @override
  Future<String> saveModule(Module m) =>
      _save(FirestoreCollections.modules, m.id, m.toJson());

  @override
  Future<void> setActive(
    String collection,
    String id, {
    required bool active,
  }) => _col(collection).doc(id).update({CommonFields.isActive: active});

  /// Throws if any document in [childCollection] has [field] == [id].
  Future<void> _ensureNoChildren(
    String childCollection,
    String field,
    String id,
  ) async {
    final child = await _col(childCollection)
        .where(field, isEqualTo: id)
        .limit(1)
        .get();
    if (child.docs.isNotEmpty) throw CatalogInUseException(childCollection);
  }

  @override
  Future<void> deleteUniversity(String id) async {
    await _ensureNoChildren(
      FirestoreCollections.semesters,
      SemesterFields.universityId,
      id,
    );
    await _col(FirestoreCollections.universities).doc(id).delete();
  }

  @override
  Future<void> deleteSemester(String id) async {
    await _ensureNoChildren(
      FirestoreCollections.subjects,
      SubjectFields.semesterId,
      id,
    );
    await _col(FirestoreCollections.semesters).doc(id).delete();
  }

  @override
  Future<void> deleteSubject(String id) async {
    await _ensureNoChildren(
      FirestoreCollections.modules,
      ModuleFields.subjectId,
      id,
    );
    await _col(FirestoreCollections.subjects).doc(id).delete();
  }

  @override
  Future<void> deleteModule(String id) async {
    await _ensureNoChildren(
      FirestoreCollections.notes,
      NoteFields.moduleId,
      id,
    );
    await _col(FirestoreCollections.modules).doc(id).delete();
  }
}

@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) =>
    FirestoreCatalogRepository(ref.watch(firestoreProvider));

// Lists for admin screens and cascading dropdowns. `ref.invalidate(...)`
// after a write to reload.

@riverpod
Future<List<University>> adminUniversities(Ref ref) =>
    ref.watch(catalogRepositoryProvider).universities();

@riverpod
Future<List<Semester>> adminSemesters(Ref ref, String universityId) =>
    ref.watch(catalogRepositoryProvider).semesters(universityId);

@riverpod
Future<List<Subject>> adminSubjects(Ref ref, String semesterId) =>
    ref.watch(catalogRepositoryProvider).subjects(semesterId);

@riverpod
Future<List<Module>> adminModules(Ref ref, String subjectId) =>
    ref.watch(catalogRepositoryProvider).modules(subjectId);
