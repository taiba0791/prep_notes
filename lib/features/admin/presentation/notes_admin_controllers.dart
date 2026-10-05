import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../data/models/note.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/search_keywords.dart';
import 'widgets/catalog_picker.dart';

part 'notes_admin_controllers.g.dart';

/// Loaded pages of the admin notes list.
class NotesListState {
  const NotesListState(
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

/// Admin notes list for a filter, paginated with "Load more".
@riverpod
class AdminNotesController extends _$AdminNotesController {
  @override
  Future<NotesListState> build(NoteFilter filter) async {
    final page = await ref
        .watch(noteRepositoryProvider)
        .listForAdmin(filter: filter);
    return NotesListState(
      page.notes,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final repo = ref.read(noteRepositoryProvider);
    state = AsyncData(
      NotesListState(
        current.notes,
        cursor: current.cursor,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final page = await repo.listForAdmin(
        filter: filter,
        cursor: current.cursor,
      );
      if (!ref.mounted) return;
      state = AsyncData(
        NotesListState(
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

/// A note being edited plus its place in the catalog (for the form).
typedef NoteForEdit = ({Note note, CatalogSelection selection});

/// Loads a note and resolves its University / Semester / Subject / Module.
@riverpod
Future<NoteForEdit?> adminNoteForEdit(Ref ref, String noteId) async {
  final note = await ref.watch(noteRepositoryProvider).get(noteId);
  if (note == null) return null;
  final catalog = ref.watch(catalogRepositoryProvider);

  T? find<T>(List<T> items, String id, String Function(T) idOf) {
    for (final x in items) {
      if (idOf(x) == id) return x;
    }
    return null;
  }

  final u = find(
    (await catalog.universities()),
    note.universityId,
    (x) => x.id,
  );
  final s = find(
    (await catalog.semesters(note.universityId)),
    note.semesterId,
    (x) => x.id,
  );
  final sub = find(
    (await catalog.subjects(note.semesterId)),
    note.subjectId,
    (x) => x.id,
  );
  final m = find(
    (await catalog.modules(note.subjectId)),
    note.moduleId,
    (x) => x.id,
  );
  return (
    note: note,
    selection: CatalogSelection(
      university: u,
      semester: s,
      subject: sub,
      module: m,
    ),
  );
}

/// Everything the admin typed in the note form.
class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.description,
    required this.selection,
    required this.pricePaise,
    required this.isFree,
    required this.tags,
    required this.previewPages,
    required this.publish,
  });

  final String title;
  final String description;
  final CatalogSelection selection;
  final int pricePaise;
  final bool isFree;
  final List<String> tags;
  final int previewPages;
  final bool publish;
}

/// Saves a note: creates a draft (new notes), uploads thumbnail + PDF, then
/// writes the final fields. State value = PDF upload progress (0–1), or
/// null when not uploading.
@riverpod
class NoteFormController extends _$NoteFormController {
  @override
  FutureOr<double?> build() => null;

  /// Returns true on success.
  Future<bool> save({
    required Note? existing,
    required NoteDraft draft,
    PickedFile? pdf,
    PickedFile? thumbnail,
  }) async {
    final notes = ref.read(noteRepositoryProvider);
    final files = ref.read(catalogFilesRepositoryProvider);
    final reporter = ref.read(errorReporterProvider);
    final sel = draft.selection;
    final isNew = existing == null;

    state = const AsyncLoading();
    try {
      final id = existing?.id ?? notes.newNoteId();
      var note =
          (existing ??
                  Note(
                    id: id,
                    title: '',
                    universityId: '',
                    semesterId: '',
                    subjectId: '',
                    moduleId: '',
                  ))
              .copyWith(
                title: draft.title.trim(),
                description: draft.description.trim(),
                universityId: sel.university!.id,
                semesterId: sel.semester!.id,
                subjectId: sel.subject!.id,
                moduleId: sel.module!.id,
                universityName: sel.university!.name,
                semesterNumber: sel.semester!.number,
                subjectName: sel.subject!.name,
                moduleTitle: sel.module!.title,
                price: draft.isFree ? 0 : draft.pricePaise,
                isFree: draft.isFree,
                tags: draft.tags,
                previewPages: draft.previewPages,
                searchKeywords: buildSearchKeywords([
                  draft.title,
                  sel.subject!.name,
                  sel.subject!.code,
                  sel.university!.name,
                  sel.university!.shortName,
                  sel.module!.title,
                  ...draft.tags,
                ]),
              );

      // 1. New notes: save a draft first so the files belong to a real note.
      if (isNew) {
        await notes.save(note.copyWith(isPublished: false), isNew: true);
      }

      // 2. Files.
      if (thumbnail != null) {
        final url = await files.uploadNoteThumbnail(
          id,
          thumbnail.bytes,
          thumbnail.contentType,
        );
        note = note.copyWith(thumbnailUrl: url);
      }
      if (pdf != null) {
        state = const AsyncData(0);
        final path = await files.uploadNotePdf(
          id,
          pdf.bytes,
          onProgress: (p) {
            if (ref.mounted) state = AsyncData(p);
          },
        );
        note = note.copyWith(storagePath: path);
      }

      // 3. Final fields (publishing needs a PDF — rules check this too).
      note = note.copyWith(isPublished: draft.publish && note.hasPdf);
      await notes.save(note, isNew: false);

      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on Object catch (e, st) {
      reporter.recordError(e, st);
      if (ref.mounted) state = AsyncError(e, st);
      return false;
    }
  }
}
