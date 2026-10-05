import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/utils/money.dart';
import 'package:prepnotes/data/models/catalog.dart';
import 'package:prepnotes/data/models/note.dart';
import 'package:prepnotes/data/models/university.dart';
import 'package:prepnotes/data/repositories/catalog_repository.dart';
import 'package:prepnotes/data/repositories/note_repository.dart';
import 'package:prepnotes/data/search_keywords.dart';

Note sampleNote(String id, {String subjectId = 'ds'}) => Note(
  id: id,
  title: 'Note $id',
  universityId: 'mu',
  semesterId: 's3',
  subjectId: subjectId,
  moduleId: 'm1',
  price: 14900,
);

void main() {
  group('Money (paise)', () {
    test('format', () {
      expect(Money.format(14900), '₹149');
      expect(Money.format(14950), '₹149.50');
      expect(Money.format(1500000), '₹15,000');
      expect(Money.format(0), '₹0');
    });

    test('parseRupees', () {
      expect(Money.parseRupees('149'), 14900);
      expect(Money.parseRupees(' ₹1,499.5 '), 149950);
      expect(Money.parseRupees('0.05'), 5);
      for (final bad in ['', 'abc', '-5', '1.234', '1.2.3']) {
        expect(Money.parseRupees(bad), isNull, reason: bad);
      }
    });

    test('toRupeesText round-trips', () {
      for (final p in [14900, 14950, 5]) {
        expect(Money.parseRupees(Money.toRupeesText(p)), p);
      }
    });
  });

  test('search keywords: words + prefixes, lower-case, no duplicates', () {
    final k = buildSearchKeywords(['Data Structures', 'data', null, 'MU']);
    expect(
      k,
      containsAll(['da', 'dat', 'data', 'st', 'struc', 'structures', 'mu']),
    );
    expect(k.where((w) => w == 'data'), hasLength(1));
    expect(k.every((w) => w == w.toLowerCase()), isTrue);
    expect(buildSearchKeywords(['a' * 100]).length, lessThanOrEqualTo(20));
  });

  test('Note JSON keys are NoteFields constants', () {
    final json = sampleNote('n1')
        .copyWith(
          description: 'd',
          thumbnailUrl: 't',
          storagePath: 'p',
          universityName: 'u',
          subjectName: 's',
          moduleTitle: 'm',
          semesterNumber: 3,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        )
        .toJson();
    expect(json.keys.toSet(), {
      NoteFields.title,
      NoteFields.description,
      NoteFields.universityId,
      NoteFields.semesterId,
      NoteFields.subjectId,
      NoteFields.moduleId,
      NoteFields.universityName,
      NoteFields.semesterNumber,
      NoteFields.subjectName,
      NoteFields.moduleTitle,
      NoteFields.price,
      NoteFields.isFree,
      NoteFields.thumbnailUrl,
      NoteFields.pageCount,
      NoteFields.fileSizeBytes,
      NoteFields.storagePath,
      NoteFields.previewPages,
      NoteFields.hasPreview,
      NoteFields.isPublished,
      NoteFields.purchaseCount,
      NoteFields.tags,
      NoteFields.searchKeywords,
      NoteFields.createdAt,
      NoteFields.updatedAt,
    });
  });

  group('CatalogRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreCatalogRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirestoreCatalogRepository(db);
    });

    test('create, list (sorted) and update', () async {
      final b = await repo.saveUniversity(
        const University(name: 'B Univ', order: 2),
      );
      await repo.saveUniversity(const University(name: 'A Univ', order: 1));
      expect((await repo.universities()).map((u) => u.name), [
        'A Univ',
        'B Univ',
      ]);

      await repo.saveUniversity(University(id: b, name: 'B Renamed', order: 2));
      expect((await repo.universities()).last.name, 'B Renamed');
    });

    test('children are listed under their parent, in order', () async {
      await repo.saveSemester(
        const Semester(universityId: 'mu', number: 4, name: 'S4'),
      );
      await repo.saveSemester(
        const Semester(universityId: 'mu', number: 3, name: 'S3'),
      );
      await repo.saveSemester(
        const Semester(universityId: 'other', number: 1, name: 'X'),
      );
      expect((await repo.semesters('mu')).map((s) => s.number), [3, 4]);
    });

    test('delete is blocked while children exist', () async {
      final uni = await repo.saveUniversity(const University(name: 'MU'));
      final sem = await repo.saveSemester(
        Semester(universityId: uni, number: 1, name: 'S1'),
      );
      await expectLater(
        repo.deleteUniversity(uni),
        throwsA(isA<CatalogInUseException>()),
      );

      await repo.deleteSemester(sem);
      await repo.deleteUniversity(uni);
      expect(await repo.universities(), isEmpty);
    });

    test('a module with notes cannot be deleted', () async {
      final mod = await repo.saveModule(
        const Module(subjectId: 'ds', number: 1, title: 'M1'),
      );
      await db.doc(FirestorePaths.note('n1')).set({NoteFields.moduleId: mod});
      await expectLater(
        repo.deleteModule(mod),
        throwsA(isA<CatalogInUseException>()),
      );
    });

    test('setActive', () async {
      final id = await repo.saveSubject(
        const Subject(universityId: 'mu', semesterId: 's3', name: 'DS'),
      );
      await repo.setActive(FirestoreCollections.subjects, id, active: false);
      expect((await repo.subjects('s3')).single.isActive, isFalse);
    });
  });

  group('NoteRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreNoteRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirestoreNoteRepository(db);
    });

    Future<Map<String, dynamic>> raw(String id) async =>
        (await db.doc(FirestorePaths.note(id)).get()).data()!;

    test('new notes start with Function-owned fields at zero', () async {
      await repo.save(
        sampleNote('n1').copyWith(pageCount: 99, purchaseCount: 5),
        isNew: true,
      );
      final d = await raw('n1');
      expect(d[NoteFields.pageCount], 0);
      expect(d[NoteFields.purchaseCount], 0);
      expect(d[NoteFields.hasPreview], false);
      expect(d[NoteFields.createdAt], isA<Timestamp>());
    });

    test('updates never touch Function-owned fields or createdAt', () async {
      await repo.save(sampleNote('n1'), isNew: true);
      // The Cloud Function fills these in…
      await db.doc(FirestorePaths.note('n1')).update({
        NoteFields.pageCount: 120,
        NoteFields.purchaseCount: 7,
      });
      // …and an admin edit (with stale values in memory) must not undo them.
      await repo.save(sampleNote('n1').copyWith(title: 'Edited'), isNew: false);
      final d = await raw('n1');
      expect(d[NoteFields.title], 'Edited');
      expect(d[NoteFields.pageCount], 120);
      expect(d[NoteFields.purchaseCount], 7);
    });

    test('admin list: newest first, filtered, paginated', () async {
      for (var i = 0; i < NoteRepository.pageSize + 5; i++) {
        await repo.save(sampleNote('n$i'), isNew: true);
        // Distinct times, as real notes have. (Real Firestore also breaks
        // ties by document id when paging; the in-memory fake doesn't.)
        await db.doc(FirestorePaths.note('n$i')).update({
          NoteFields.updatedAt: Timestamp.fromMillisecondsSinceEpoch(1000 * i),
        });
      }
      await repo.save(sampleNote('other', subjectId: 'os'), isNew: true);

      final first = await repo.listForAdmin(
        filter: const NoteFilter(subjectId: 'ds'),
      );
      expect(first.notes, hasLength(NoteRepository.pageSize));
      expect(first.hasMore, isTrue);

      expect(first.notes.map((n) => n.id).contains('other'), isFalse);
      // Newest first.
      expect(first.notes.first.id, 'n${NoteRepository.pageSize + 4}');
      // Note: page 2 (startAfterDocument with a descending order) can't be
      // checked here — fake_cloud_firestore returns an empty page for it.
      // Real Firestore supports it; it's verified manually on the emulator.
    });
  });
}
