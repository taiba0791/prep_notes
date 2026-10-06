import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/data/models/access.dart';
import 'package:prepnotes/data/models/note_query.dart';
import 'package:prepnotes/data/models/recently_viewed.dart';
import 'package:prepnotes/data/repositories/browse_repository.dart';
import 'package:prepnotes/data/repositories/library_repository.dart';
import 'package:prepnotes/data/search_keywords.dart';

late FakeFirebaseFirestore db;

/// Adds a note document. [t] gives it a distinct updatedAt.
Future<void> addNote(
  String id, {
  required int t,
  bool published = true,
  String subjectId = 'ds',
  String moduleId = 'm1',
  int price = 9900,
  bool featured = false,
  int purchases = 0,
  String title = 'Data Structures Notes',
}) => db.doc(FirestorePaths.note(id)).set({
  NoteFields.title: title,
  NoteFields.universityId: 'mu',
  NoteFields.semesterId: 's3',
  NoteFields.subjectId: subjectId,
  NoteFields.moduleId: moduleId,
  NoteFields.price: price,
  NoteFields.isFree: price == 0,
  NoteFields.isPublished: published,
  NoteFields.isFeatured: featured,
  NoteFields.purchaseCount: purchases,
  NoteFields.searchKeywords: buildSearchKeywords([title, 'Mumbai University']),
  NoteFields.updatedAt: Timestamp.fromMillisecondsSinceEpoch(1000 * t),
});

void main() {
  late FirestoreBrowseRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreBrowseRepository(
      db,
      storage: () => throw UnimplementedError(),
    );
  });

  Future<List<String>> ids(NoteQuery q) async =>
      (await repo.notes(q)).notes.map((n) => n.id).toList();

  group('notes(query)', () {
    setUp(() async {
      await addNote('cheap', t: 1, price: 4900, purchases: 5);
      await addNote('free', t: 2, price: 0, purchases: 9);
      await addNote(
        'pricey',
        t: 3,
        price: 29900,
        subjectId: 'os',
        purchases: 1,
      );
      await addNote('draft', t: 4, published: false);
    });

    test('only published notes, newest first', () async {
      expect(await ids(const NoteQuery()), ['pricey', 'free', 'cheap']);
    });

    test('filter by subject', () async {
      expect(await ids(const NoteQuery(subjectId: 'os')), ['pricey']);
    });

    test('free / paid / max price', () async {
      expect(await ids(const NoteQuery(priceFilter: PriceFilter.free)), [
        'free',
      ]);
      expect(await ids(const NoteQuery(priceFilter: PriceFilter.paid)), [
        'cheap',
        'pricey',
      ]);
      expect(await ids(const NoteQuery(maxPrice: 9900)), ['free', 'cheap']);
    });

    test('sorts', () async {
      expect(await ids(const NoteQuery(sort: NoteSort.popular)), [
        'free',
        'cheap',
        'pricey',
      ]);
      expect(await ids(const NoteQuery(sort: NoteSort.priceHigh)), [
        'pricey',
        'cheap',
        'free',
      ]);
    });

    test('a price range forces price order', () {
      const q = NoteQuery(sort: NoteSort.newest, maxPrice: 9900);
      expect(q.effectiveSort, NoteSort.priceLow);
      expect(
        const NoteQuery(priceFilter: PriceFilter.free).effectiveSort,
        NoteSort.newest,
      );
    });
  });

  test('popular: featured first, then most purchased', () async {
    await addNote('a', t: 1, purchases: 50);
    await addNote('b', t: 2, purchases: 10);
    await addNote('star', t: 3, featured: true);
    await addNote('hidden', t: 4, featured: true, published: false);
    final list = await repo.popular(limit: 3);
    expect(list.map((n) => n.id), ['star', 'a', 'b']);
  });

  test('related: same subject, not itself', () async {
    await addNote('n1', t: 1);
    await addNote('n2', t: 2);
    await addNote('other', t: 3, subjectId: 'os');
    final n1 = (await repo.note('n1'))!;
    expect((await repo.related(n1)).map((n) => n.id), ['n2']);
  });

  test('search: every word must match the start of a word', () async {
    await addNote('ds', t: 1, title: 'Data Structures Notes');
    await addNote('db', t: 2, title: 'Database Systems');
    await addNote(
      'draft',
      t: 3,
      title: 'Data Structures Draft',
      published: false,
    );

    expect((await repo.search('data struc')).map((n) => n.id), ['ds']);
    expect((await repo.search('DATA')).map((n) => n.id).toSet(), {'ds', 'db'});
    expect((await repo.search('mumbai')).length, 2);
    expect(await repo.search('physics'), isEmpty);
    expect(await repo.search('   '), isEmpty);
  });

  test('note(): unpublished notes are not shown', () async {
    await addNote('draft', t: 1, published: false);
    expect(await repo.note('draft'), isNull);
    expect(await repo.note('missing'), isNull);
  });

  test('counts: published notes, active universities and subjects', () async {
    await addNote('a', t: 1);
    await addNote('b', t: 2, published: false);
    await db.doc('universities/u1').set({UniversityFields.isActive: true});
    await db.doc('universities/u2').set({UniversityFields.isActive: false});
    await db.doc('subjects/s1').set({SubjectFields.isActive: true});
    final c = await repo.counts();
    expect((c.notes, c.universities, c.subjects), (1, 1, 1));
  });

  group('LibraryRepository', () {
    late FirestoreLibraryRepository library;
    setUp(() => library = FirestoreLibraryRepository(db));

    test(
      'noteAccess: own purchase or bundle, only while not expired',
      () async {
        final now = DateTime(2026, 10, 7);
        Future<NoteAccess> access() =>
            library.noteAccess('u1', 'n1', semesterId: 's3', now: now);
        expect((await access()).kind, NoteAccessKind.none);

        // Expired purchase → no access.
        await db.doc(FirestorePaths.entitlement('u1', 'n1')).set({
          EntitlementFields.expiresAt: Timestamp.fromDate(
            DateTime(2026, 10, 1),
          ),
        });
        expect((await access()).kind, NoteAccessKind.none);

        // Active bundle for the semester → access via bundle.
        await db.doc(FirestorePaths.bundle('u1', 's3')).set({
          BundleFields.expiresAt: Timestamp.fromDate(DateTime(2027, 4, 7)),
        });
        final viaBundle = await access();
        expect(viaBundle.kind, NoteAccessKind.bundle);
        expect(viaBundle.until, DateTime(2027, 4, 7));

        // Active own purchase wins.
        await db.doc(FirestorePaths.entitlement('u1', 'n1')).set({
          EntitlementFields.expiresAt: Timestamp.fromDate(DateTime(2027, 1, 1)),
        });
        expect((await access()).kind, NoteAccessKind.owner);
      },
    );

    test('recently viewed keeps the newest 20, newest first', () async {
      for (var i = 0; i < 23; i++) {
        await library.recordView(
          'u1',
          RecentlyViewed(noteId: 'n$i', title: 'Note $i'),
        );
        // Distinct times (the fake stamps serverTimestamp with "now").
        await db.doc('${FirestorePaths.recentlyViewed('u1')}/n$i').update({
          RecentlyViewedFields.viewedAt: Timestamp.fromMillisecondsSinceEpoch(
            1000 * i,
          ),
        });
      }
      // One more view triggers the trim.
      await library.recordView(
        'u1',
        const RecentlyViewed(noteId: 'n5', title: 'Note 5'),
      );
      final list = await library.recentlyViewed('u1');
      expect(list, hasLength(LibraryRepository.recentlyViewedLimit));
      expect(list.first.noteId, 'n5');
    });
  });
}
