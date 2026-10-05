import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/university.dart';

part 'university_repository.g.dart';

/// Reads `universities`. (Admin create/edit arrives in Phase 2.)
abstract interface class UniversityRepository {
  /// Active universities, sorted by `order` then name. Capped at [limit]
  /// (a dropdown never needs more; browse screens will paginate).
  Future<List<University>> listActive({int limit = 200});
}

class FirestoreUniversityRepository implements UniversityRepository {
  FirestoreUniversityRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<University>> listActive({int limit = 200}) async {
    // Ordered by `order` only (no composite index needed); inactive ones are
    // filtered here — there are only ever a handful of universities.
    final snap = await _db
        .collection(FirestoreCollections.universities)
        .orderBy(UniversityFields.order)
        .limit(limit)
        .get();
    final list = [
      for (final d in snap.docs)
        University.fromJson(d.data()).copyWith(id: d.id),
    ].where((u) => u.isActive).toList();
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return list;
  }
}

@Riverpod(keepAlive: true)
UniversityRepository universityRepository(Ref ref) =>
    FirestoreUniversityRepository(ref.watch(firestoreProvider));

/// Active universities for dropdowns. `ref.invalidate` to reload.
@riverpod
Future<List<University>> activeUniversities(Ref ref) =>
    ref.watch(universityRepositoryProvider).listActive();
