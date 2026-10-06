import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../data/models/access.dart';
import '../../../data/models/catalog.dart';
import '../../../data/models/note.dart';
import '../../../data/models/note_query.dart';
import '../../../data/models/recently_viewed.dart';
import '../../../data/models/university.dart';
import '../../../data/repositories/browse_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/library_repository.dart';
import '../../auth/data/auth_repository.dart';

part 'browse_providers.g.dart';

// ── Home ───────────────────────────────────────────────────

@riverpod
Future<CatalogCounts> catalogCounts(Ref ref) =>
    ref.watch(browseRepositoryProvider).counts();

@riverpod
Future<List<Note>> popularNotes(Ref ref) =>
    ref.watch(browseRepositoryProvider).popular();

/// Active universities for students (sorted).
@riverpod
Future<List<University>> browseUniversities(Ref ref) async => [
  for (final u in await ref.watch(catalogRepositoryProvider).universities())
    if (u.isActive) u,
];

@riverpod
Future<int> semesterNoteCount(Ref ref, String semesterId) =>
    ref.watch(browseRepositoryProvider).semesterNoteCount(semesterId);

// ── Catalog levels ─────────────────────────────────────────

@riverpod
Future<University?> universityById(Ref ref, String id) =>
    ref.watch(catalogRepositoryProvider).university(id);

@riverpod
Future<Semester?> semesterById(Ref ref, String id) =>
    ref.watch(catalogRepositoryProvider).semester(id);

@riverpod
Future<Subject?> subjectById(Ref ref, String id) =>
    ref.watch(catalogRepositoryProvider).subject(id);

@riverpod
Future<List<Semester>> activeSemesters(Ref ref, String universityId) async => [
  for (final s
      in await ref.watch(catalogRepositoryProvider).semesters(universityId))
    if (s.isActive) s,
];

@riverpod
Future<List<Subject>> activeSubjects(Ref ref, String semesterId) async => [
  for (final s
      in await ref.watch(catalogRepositoryProvider).subjects(semesterId))
    if (s.isActive) s,
];

@riverpod
Future<List<Module>> activeModules(Ref ref, String subjectId) async => [
  for (final m in await ref.watch(catalogRepositoryProvider).modules(subjectId))
    if (m.isActive) m,
];

/// First page of a module's notes (subject page sections).
@riverpod
Future<List<Note>> moduleNotes(Ref ref, String moduleId) async =>
    (await ref
            .watch(browseRepositoryProvider)
            .notes(NoteQuery(moduleId: moduleId)))
        .notes;

// ── Notes lists with filters + "Load more" ─────────────────

class NoteListState {
  const NoteListState(
    this.notes, {
    this.cursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Note> notes;
  final Object? cursor;
  final bool hasMore;
  final bool loadingMore;
}

@riverpod
class NoteExplorer extends _$NoteExplorer {
  @override
  Future<NoteListState> build(NoteQuery query) async {
    final page = await ref.watch(browseRepositoryProvider).notes(query);
    return NoteListState(
      page.notes,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final repo = ref.read(browseRepositoryProvider);
    state = AsyncData(
      NoteListState(
        current.notes,
        cursor: current.cursor,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final page = await repo.notes(query, cursor: current.cursor);
      if (!ref.mounted) return;
      state = AsyncData(
        NoteListState(
          [...current.notes, ...page.notes],
          cursor: page.cursor ?? current.cursor,
          hasMore: page.hasMore,
        ),
      );
    } on Object catch (e, st) {
      ref.read(errorReporterProvider).recordError(e, st);
      if (ref.mounted) state = AsyncData(current);
    }
  }
}

// ── Note details ───────────────────────────────────────────

@riverpod
Future<Note?> noteDetails(Ref ref, String noteId) =>
    ref.watch(browseRepositoryProvider).note(noteId);

@riverpod
Future<List<Note>> relatedNotes(Ref ref, String noteId) async {
  final note = await ref.watch(noteDetailsProvider(noteId).future);
  if (note == null) return const [];
  return ref.watch(browseRepositoryProvider).related(note);
}

@riverpod
Future<String?> previewUrl(Ref ref, String noteId) =>
    ref.watch(browseRepositoryProvider).previewUrl(noteId);

/// Can the signed-in user read this note now (bought within 6 months, or
/// in an active semester bundle)? Guests: no.
@riverpod
Future<NoteAccess> noteAccess(Ref ref, String noteId) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return NoteAccess.none;
  final note = await ref.watch(noteDetailsProvider(noteId).future);
  return ref
      .watch(libraryRepositoryProvider)
      .noteAccess(uid, noteId, semesterId: note?.semesterId ?? '');
}

// ── Search ─────────────────────────────────────────────────

@riverpod
Future<List<Note>> searchResults(Ref ref, String text) => text.trim().isEmpty
    ? Future.value(const [])
    : ref.watch(browseRepositoryProvider).search(text);

// ── Recently viewed ────────────────────────────────────────

@riverpod
Future<List<RecentlyViewed>> recentlyViewed(Ref ref) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return const [];
  return ref.watch(libraryRepositoryProvider).recentlyViewed(uid);
}
