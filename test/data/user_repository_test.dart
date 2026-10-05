import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreUserRepository(db);
  });

  Future<Map<String, dynamic>> raw(String uid) async =>
      (await db.doc(FirestorePaths.user(uid)).get()).data()!;

  test('createProfileIfMissing writes a student profile', () async {
    await repo.createProfileIfMissing(
      uid: 'u1',
      name: ' Taiba ',
      email: 'taiba@x.com',
    );
    final data = await raw('u1');

    expect(data[UserFields.name], 'Taiba');
    expect(data[UserFields.email], 'taiba@x.com');
    expect(data[UserFields.role], UserRole.student);
    expect(data[UserFields.totalStudyMinutes], 0);
    expect(data[UserFields.createdAt], isA<Timestamp>());
    expect(data.containsKey(UserFields.photoUrl), isFalse);
  });

  test('createProfileIfMissing never overwrites an existing profile', () async {
    await repo.createProfileIfMissing(uid: 'u1', name: 'First', email: 'a@x');
    await repo.createProfileIfMissing(uid: 'u1', name: 'Second', email: 'b@x');
    expect((await raw('u1'))[UserFields.name], 'First');
  });

  test('getProfile returns null when missing, model when present', () async {
    expect(await repo.getProfile('nobody'), isNull);

    await repo.createProfileIfMissing(uid: 'u1', name: 'Taiba', email: 'a@x');
    final p = await repo.getProfile('u1');
    expect(p!.uid, 'u1');
    expect(p.name, 'Taiba');
  });

  test('updateProfile changes only the given fields', () async {
    await repo.createProfileIfMissing(uid: 'u1', name: 'Taiba', email: 'a@x');
    await repo.updateProfile('u1', semester: 4, universityId: 'mu');

    final data = await raw('u1');
    expect(data[UserFields.semester], 4);
    expect(data[UserFields.universityId], 'mu');
    expect(data[UserFields.name], 'Taiba');
  });

  test('watchProfile emits updates', () async {
    await repo.createProfileIfMissing(uid: 'u1', name: 'Taiba', email: 'a@x');
    final names = repo.watchProfile('u1').map((p) => p?.name);

    final expectation = expectLater(names, emitsInOrder(['Taiba', 'Taiba S']));
    await repo.updateProfile('u1', name: 'Taiba S');
    await expectation;
  });
}
