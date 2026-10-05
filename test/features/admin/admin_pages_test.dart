import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/services/file_picker_service.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/repositories/catalog_repository.dart';
import 'package:prepnotes/data/repositories/note_repository.dart';
import 'package:prepnotes/features/admin/presentation/admin_scaffold.dart';
import 'package:prepnotes/features/admin/presentation/catalog_pages.dart';
import 'package:prepnotes/features/admin/presentation/notes_admin_pages.dart';

import '../../fakes/fake_media.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeFirebaseFirestore db;
  late FakeFilePickerService picker;
  late FakeCatalogFilesRepository files;

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
      SubjectFields.code: 'CS301',
      SubjectFields.isActive: true,
    });
    await db.doc('modules/m1').set({
      ModuleFields.subjectId: 'ds',
      ModuleFields.number: 1,
      ModuleFields.title: 'Arrays',
      ModuleFields.isActive: true,
    });
  }

  Future<void> pump(
    WidgetTester tester,
    String start, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: start,
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AdminScaffold(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: RoutePaths.admin,
              builder: (_, _) => const SizedBox(),
            ),
            GoRoute(
              path: RoutePaths.adminUniversities,
              builder: (_, _) => const AdminUniversitiesPage(),
            ),
            GoRoute(
              path: RoutePaths.adminSemesters,
              builder: (_, _) => const AdminSemestersPage(),
            ),
            GoRoute(
              path: RoutePaths.adminNotes,
              builder: (_, _) => const AdminNotesPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const AdminNoteFormPage(),
                ),
                GoRoute(
                  path: ':noteId/edit',
                  builder: (_, s) =>
                      AdminNoteFormPage(noteId: s.pathParameters['noteId']),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: RoutePaths.home, builder: (_, _) => const Text('HOME')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            FirestoreCatalogRepository(db),
          ),
          noteRepositoryProvider.overrideWithValue(FirestoreNoteRepository(db)),
          catalogFilesRepositoryProvider.overrideWithValue(files),
          filePickerServiceProvider.overrideWithValue(picker),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    picker = FakeFilePickerService();
    files = FakeCatalogFilesRepository();
  });

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// Opens the dropdown labelled [dropdownLabel] and picks [option].
  Future<void> choose(
    WidgetTester tester,
    String dropdownLabel,
    String option,
  ) async {
    final dropdown = find.ancestor(
      of: find.text(dropdownLabel),
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.ensureVisible(dropdown.last);
    await tester.tap(dropdown.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  group('Admin shell', () {
    testWidgets('desktop: dark side menu with every section', (tester) async {
      await pump(tester, RoutePaths.adminUniversities);
      for (final s in adminSections) {
        expect(find.text(s.label), findsWidgets, reason: s.label);
      }
      expect(find.text(AppStrings.adminBackToSite), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: sections become a scrolling chip row', (tester) async {
      await pump(tester, RoutePaths.adminUniversities, width: 380);
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Universities', () {
    testWidgets('add a university with a logo', (tester) async {
      await pump(tester, RoutePaths.adminUniversities);
      expect(find.text(AppStrings.nothingHereYet), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, AppStrings.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        field(AppStrings.fieldName),
        'University of Mumbai',
      );
      await tester.enterText(field(AppStrings.fieldShortName), 'MU');
      picker.nextImage = (
        name: 'logo.png',
        bytes: Uint8List(100),
        contentType: 'image/png',
      );
      await tester.tap(find.text(AppStrings.chooseImage));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text('University of Mumbai'), findsOneWidget);
      final docs = (await db.collection('universities').get()).docs;
      expect(
        docs.single.get(UniversityFields.logoUrl),
        contains('universities/'),
      );
      expect(files.uploads.single, startsWith('logo:'));
    });

    testWidgets('delete is blocked while it has semesters', (tester) async {
      await seedCatalog();
      await pump(tester, RoutePaths.adminUniversities);

      await tester.ensureVisible(find.byTooltip(AppStrings.delete));
      await tester.tap(find.byTooltip(AppStrings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.inUse('semesters')), findsOneWidget);
      expect((await db.doc('universities/mu').get()).exists, isTrue);
    });
  });

  testWidgets('Semesters: pick a university, then add', (tester) async {
    await seedCatalog();
    await pump(tester, RoutePaths.adminSemesters);
    expect(find.text(AppStrings.chooseParentFirst), findsOneWidget);

    await choose(tester, AppStrings.pickUniversity, 'University of Mumbai');
    expect(find.text('Semester 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.add));
    await tester.pumpAndSettle();
    await choose(tester, AppStrings.fieldNumber, '4');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
    await tester.pumpAndSettle();

    expect(find.text('Semester 4'), findsOneWidget);
  });

  group('Notes', () {
    Future<void> fillNewNote(WidgetTester tester) async {
      await tester.enterText(
        field(AppStrings.fieldTitle),
        'Data Structures: Complete',
      );
      await choose(tester, AppStrings.pickUniversity, 'University of Mumbai');
      await choose(tester, AppStrings.pickSemester, 'Semester 3');
      await choose(tester, AppStrings.pickSubject, 'Data Structures');
      await choose(tester, AppStrings.pickModule, '1. Arrays');
      await tester.enterText(field(AppStrings.fieldPrice), '149');
    }

    testWidgets('publish is disabled until a PDF is chosen', (tester) async {
      await seedCatalog();
      await pump(tester, RoutePaths.adminNoteNew);
      expect(find.text(AppStrings.publishNeedsPdf), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, AppStrings.fieldPublished),
      );
      expect(toggle.onChanged, isNull);
    });

    testWidgets('validation: title, catalog and price are required', (
      tester,
    ) async {
      await seedCatalog();
      await pump(tester, RoutePaths.adminNoteNew);
      await tester.enterText(field(AppStrings.fieldPrice), '0');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.save),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.required), findsWidgets);
      expect(find.text(AppStrings.priceMustBePositive), findsOneWidget);
      expect((await db.collection('notes').get()).docs, isEmpty);
    });

    testWidgets('create: uploads PDF + thumbnail, publishes, lists it', (
      tester,
    ) async {
      await seedCatalog();
      await pump(tester, RoutePaths.adminNoteNew);
      await fillNewNote(tester);

      picker.nextPdf = (
        name: 'ds.pdf',
        bytes: Uint8List(2048),
        contentType: 'application/pdf',
      );
      await tester.ensureVisible(find.text(AppStrings.choosePdf));
      await tester.tap(find.text(AppStrings.choosePdf));
      await tester.pumpAndSettle();
      picker.nextImage = (
        name: 'c.jpg',
        bytes: Uint8List(10),
        contentType: 'image/jpeg',
      );
      await tester.tap(find.text(AppStrings.chooseImage));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.fieldPublished));
      await tester.tap(find.text(AppStrings.fieldPublished));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.save),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      final note = (await db.collection('notes').get()).docs.single;
      expect(note.get(NoteFields.title), 'Data Structures: Complete');
      expect(note.get(NoteFields.price), 14900);
      expect(note.get(NoteFields.isPublished), isTrue);
      expect(
        note.get(NoteFields.storagePath),
        'notes_private/${note.id}/file.pdf',
      );
      expect(note.get(NoteFields.universityName), 'University of Mumbai');
      expect(note.get(NoteFields.semesterNumber), 3);
      expect(note.get(NoteFields.moduleTitle), 'Arrays');
      expect(
        note.get(NoteFields.searchKeywords),
        containsAll(['data', 'struc', 'mu', 'cs301']),
      );
      expect(
        files.uploads,
        containsAll(['pdf:${note.id}', 'thumb:${note.id}']),
      );

      // Back on the list, which shows it as published.
      expect(find.text('Data Structures: Complete'), findsOneWidget);
      expect(find.text(AppStrings.published), findsOneWidget);
    });

    testWidgets('free notes save with price 0', (tester) async {
      await seedCatalog();
      await pump(tester, RoutePaths.adminNoteNew);
      await fillNewNote(tester);
      await tester.tap(find.text(AppStrings.fieldFree));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.save),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      final note = (await db.collection('notes').get()).docs.single;
      expect(note.get(NoteFields.isFree), isTrue);
      expect(note.get(NoteFields.price), 0);
      expect(note.get(NoteFields.isPublished), isFalse, reason: 'no PDF yet');
    });

    testWidgets('edit an existing note keeps the PDF and its page count', (
      tester,
    ) async {
      await seedCatalog();
      await db.doc('notes/n1').set({
        NoteFields.title: 'Old title',
        NoteFields.universityId: 'mu',
        NoteFields.semesterId: 's3',
        NoteFields.subjectId: 'ds',
        NoteFields.moduleId: 'm1',
        NoteFields.price: 9900,
        NoteFields.isFree: false,
        NoteFields.storagePath: 'notes_private/n1/file.pdf',
        NoteFields.pageCount: 42,
        NoteFields.isPublished: true,
      });
      await pump(tester, RoutePaths.adminNoteEdit('n1'));

      expect(find.textContaining(AppStrings.pdfAttached), findsOneWidget);
      await tester.enterText(field(AppStrings.fieldTitle), 'New title');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.save),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      final d = (await db.doc('notes/n1').get()).data()!;
      expect(d[NoteFields.title], 'New title');
      expect(d[NoteFields.pageCount], 42);
      expect(d[NoteFields.storagePath], 'notes_private/n1/file.pdf');
      expect(d[NoteFields.isPublished], isTrue);
      expect(files.uploads, isEmpty);
    });
  });
}
