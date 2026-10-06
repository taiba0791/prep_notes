import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/providers/firebase_providers.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/models/note_query.dart';
import 'package:prepnotes/data/search_keywords.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/home/presentation/home_screen.dart';
import 'package:prepnotes/features/notes/presentation/browse_screens.dart';
import 'package:prepnotes/features/notes/presentation/note_details_screen.dart';
import 'package:prepnotes/features/notes/presentation/preview_and_search_screens.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeFirebaseFirestore db;
  late FakeAuthRepository auth;

  Future<void> seedCatalog() async {
    await db.doc('universities/mu').set({
      UniversityFields.name: 'University of Mumbai',
      UniversityFields.shortName: 'MU',
      UniversityFields.order: 1,
      UniversityFields.isActive: true,
    });
    await db.doc('semesters/s3').set({
      SemesterFields.universityId: 'mu',
      SemesterFields.number: 3,
      SemesterFields.name: 'Semester 3',
      SemesterFields.isActive: true,
    });
    await db.doc('subjects/ds').set({
      SubjectFields.universityId: 'mu',
      SubjectFields.semesterId: 's3',
      SubjectFields.name: 'Data Structures',
      SubjectFields.isActive: true,
    });
    for (final (id, n, title) in [('m1', 1, 'Arrays'), ('m2', 2, 'Trees')]) {
      await db.doc('modules/$id').set({
        ModuleFields.subjectId: 'ds',
        ModuleFields.number: n,
        ModuleFields.title: title,
        ModuleFields.isActive: true,
      });
    }
  }

  Future<void> addNote(
    String id, {
    String title = 'Data Structures: Complete Notes',
    int price = 14900,
    bool published = true,
    bool hasPreview = true,
    int t = 1,
  }) => db.doc(FirestorePaths.note(id)).set({
    NoteFields.title: title,
    NoteFields.universityId: 'mu',
    NoteFields.semesterId: 's3',
    NoteFields.subjectId: 'ds',
    NoteFields.moduleId: 'm1',
    NoteFields.universityName: 'University of Mumbai',
    NoteFields.semesterNumber: 3,
    NoteFields.subjectName: 'Data Structures',
    NoteFields.moduleTitle: 'Arrays',
    NoteFields.price: price,
    NoteFields.isFree: price == 0,
    NoteFields.pageCount: 120,
    NoteFields.fileSizeBytes: 8 * 1024 * 1024,
    NoteFields.previewPages: 3,
    NoteFields.hasPreview: hasPreview,
    NoteFields.isPublished: published,
    NoteFields.purchaseCount: 0,
    NoteFields.searchKeywords: buildSearchKeywords([title, 'Mumbai']),
    NoteFields.updatedAt: Timestamp.fromMillisecondsSinceEpoch(1000 * t),
  });

  Future<void> pump(
    WidgetTester tester,
    String start, {
    double width = 1400,
    AuthSession session = AuthSession.guest,
    bool buyInApp = true,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    auth = FakeAuthRepository(session);

    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(path: RoutePaths.home, builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: RoutePaths.search,
          builder: (_, s) =>
              SearchScreen(initialQuery: s.uri.queryParameters['q'] ?? ''),
        ),
        GoRoute(
          path: RoutePaths.notes,
          builder: (_, _) => const NotesHomeScreen(),
          routes: [
            GoRoute(
              path: 'sub/:id',
              builder: (_, s) =>
                  SubjectScreen(subjectId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: ':id',
              builder: (_, s) =>
                  NoteDetailsScreen(noteId: s.pathParameters['id']!),
            ),
          ],
        ),
        // Destinations linked from the pages (not under test).
        for (final p in [
          RoutePaths.register,
          RoutePaths.studyZone,
          RoutePaths.resources,
        ])
          GoRoute(path: p, builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/checkout/:id',
          builder: (_, s) => Text('checkout:${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(auth),
          buyInAppProvider.overrideWithValue(buyInApp),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => db = FakeFirebaseFirestore());

  group('Home', () {
    testWidgets('with data: real stats band, universities and popular notes', (
      tester,
    ) async {
      await seedCatalog();
      await addNote('n1');
      await pump(tester, RoutePaths.home);

      expect(find.text(AppStrings.statNotes.toUpperCase()), findsOneWidget);
      expect(find.text('University of Mumbai'), findsWidgets);
      expect(find.text('Data Structures: Complete Notes'), findsOneWidget);
      expect(find.text('₹149'), findsOneWidget);
      // Popular chips come from real subjects.
      expect(
        find.widgetWithText(ActionChip, 'Data Structures'),
        findsOneWidget,
      );
      // No invented testimonials or "trusted by" claims.
      expect(find.textContaining('Trusted by'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty catalog: no stats band, friendly empty state', (
      tester,
    ) async {
      await pump(tester, RoutePaths.home);
      expect(find.text(AppStrings.statNotes.toUpperCase()), findsNothing);
      expect(find.text(AppStrings.noNotesYetTitle), findsWidgets);
    });

    testWidgets('phone layout fits (no overflow)', (tester) async {
      await seedCatalog();
      await addNote('n1');
      await pump(tester, RoutePaths.home, width: 380);
      expect(find.text('Data Structures: Complete Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Note details', () {
    testWidgets('paid note: price, meta, Buy now, preview tiles', (
      tester,
    ) async {
      await seedCatalog();
      await addNote('n1');
      await pump(tester, RoutePaths.note('n1'));

      expect(find.text('Data Structures: Complete Notes'), findsOneWidget);
      expect(find.textContaining('120 pages · PDF · 8.0 MB'), findsOneWidget);
      expect(find.text(AppStrings.buyNow), findsOneWidget);
      expect(find.text(AppStrings.readPreview), findsOneWidget);
      expect(find.text(AppStrings.buyToUnlock), findsNWidgets(3));

      expect(find.text(AppStrings.buyOnWebsite), findsNothing);

      await tester.tap(find.text(AppStrings.buyNow));
      await tester.pumpAndSettle();
      expect(find.text('checkout:n1'), findsOneWidget);
    });

    testWidgets('phone app: "Buy on website" instead of Buy now', (
      tester,
    ) async {
      await seedCatalog();
      await addNote('n1');
      await pump(tester, RoutePaths.note('n1'), width: 400, buyInApp: false);
      expect(find.text(AppStrings.buyNow), findsNothing);
      expect(find.text(AppStrings.buyOnWebsite), findsOneWidget);
      expect(find.text(AppStrings.buyOnWebsiteHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('free note: "Get it free", no preview → message', (
      tester,
    ) async {
      await seedCatalog();
      await addNote('f1', price: 0, hasPreview: false);
      await pump(tester, RoutePaths.note('f1'));
      expect(find.text(AppStrings.readFree), findsOneWidget);
      expect(find.text(AppStrings.free), findsWidgets);
      expect(find.text(AppStrings.noPreview), findsOneWidget);
      expect(find.text(AppStrings.readPreview), findsNothing);
    });

    testWidgets('bought note: "You own these notes"', (tester) async {
      await seedCatalog();
      await addNote('n1');
      await db.doc(FirestorePaths.entitlement('u1', 'n1')).set({
        EntitlementFields.noteId: 'n1',
      });
      await pump(
        tester,
        RoutePaths.note('n1'),
        session: const AuthSession(uid: 'u1'),
      );
      expect(find.text(AppStrings.youOwnThis), findsOneWidget);
      expect(find.text(AppStrings.readNow), findsOneWidget);
      expect(find.text(AppStrings.buyNow), findsNothing);
    });

    testWidgets('signed-in visits are recorded in Recently viewed', (
      tester,
    ) async {
      await seedCatalog();
      await addNote('n1');
      await pump(
        tester,
        RoutePaths.note('n1'),
        session: const AuthSession(uid: 'u1'),
      );
      final rv = await db
          .doc('${FirestorePaths.recentlyViewed('u1')}/n1')
          .get();
      expect(
        rv.get(RecentlyViewedFields.title),
        'Data Structures: Complete Notes',
      );
    });

    testWidgets('drafts and missing notes show "not found"', (tester) async {
      await addNote('draft', published: false);
      await pump(tester, RoutePaths.note('draft'));
      expect(find.text(AppStrings.noteNotFoundTitle), findsOneWidget);
    });

    testWidgets('related notes from the same subject', (tester) async {
      await seedCatalog();
      await addNote('n1', t: 1);
      await addNote('n2', title: 'Data Structures: Exam Pack', t: 2);
      await pump(tester, RoutePaths.note('n1'));
      expect(find.text('Data Structures: Exam Pack'), findsOneWidget);
    });
  });

  testWidgets('Subject page lists modules with their notes', (tester) async {
    await seedCatalog();
    await addNote('n1');
    await pump(tester, RoutePaths.subject('ds'));

    expect(find.text(AppStrings.moduleHeading(1, 'Arrays')), findsOneWidget);
    expect(find.text(AppStrings.moduleHeading(2, 'Trees')), findsOneWidget);
    expect(find.text('Data Structures: Complete Notes'), findsOneWidget);
    expect(find.text(AppStrings.noNotesInModule), findsOneWidget);
    // Breadcrumbs back up the hierarchy.
    expect(find.text('University of Mumbai'), findsOneWidget);
    expect(find.text('Semester 3'), findsOneWidget);
  });

  group('Search', () {
    testWidgets('results, and a friendly "no results"', (tester) async {
      await addNote('n1');
      await pump(tester, RoutePaths.searchFor('data struc'));
      expect(find.text(AppStrings.resultsFor('data struc')), findsOneWidget);
      expect(find.text('Data Structures: Complete Notes'), findsOneWidget);

      await pump(tester, RoutePaths.searchFor('physics'));
      expect(find.text(AppStrings.searchNoResults('physics')), findsOneWidget);
    });

    testWidgets('empty query shows the start state', (tester) async {
      await pump(tester, RoutePaths.search);
      expect(find.text(AppStrings.searchStartTitle), findsOneWidget);
    });
  });

  testWidgets('Notes page: Free filter narrows the list', (tester) async {
    await seedCatalog();
    await addNote('paid', t: 1);
    await addNote('free', title: 'Quick Revision', price: 0, t: 2);
    await pump(tester, RoutePaths.notes);
    expect(find.text('Quick Revision'), findsOneWidget);
    expect(find.text('Data Structures: Complete Notes'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<PriceFilter>),
        matching: find.text(AppStrings.filterFree),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Revision'), findsOneWidget);
    expect(find.text('Data Structures: Complete Notes'), findsNothing);
  });
}
