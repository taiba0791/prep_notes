import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/note_cover.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/note.dart';
import '../../../data/repositories/note_repository.dart';
import '../../auth/presentation/widgets/auth_form_parts.dart';
import 'notes_admin_controllers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/catalog_picker.dart';

// ─────────────────────────── Notes list ───────────────────────────

class AdminNotesPage extends ConsumerStatefulWidget {
  const AdminNotesPage({super.key});

  @override
  ConsumerState<AdminNotesPage> createState() => _AdminNotesPageState();
}

class _AdminNotesPageState extends ConsumerState<AdminNotesPage> {
  CatalogSelection _sel = const CatalogSelection();
  String _search = '';

  NoteFilter get _filter => NoteFilter(
    universityId: _sel.university?.id,
    semesterId: _sel.semester?.id,
    subjectId: _sel.subject?.id,
  );

  Future<void> _delete(Note n) async {
    if (!await confirmDelete(context, n.title) || !mounted) return;
    if (await runAdminAction(
      context,
      () => ref.read(noteRepositoryProvider).delete(n.id),
      success: AppStrings.deleted,
    )) {
      ref.invalidate(adminNotesControllerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotesControllerProvider(_filter));
    final q = _search.toLowerCase();

    return AdminPage(
      title: AppStrings.adminNotes,
      actions: [
        FilledButton.icon(
          onPressed: () => context.go(RoutePaths.adminNoteNew),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newNote),
        ),
      ],
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogPicker(
            selection: _sel,
            depth: CatalogDepth.subject,
            allowAll: true,
            onChanged: (s) => setState(() => _sel = s),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
      ),
      child: state.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(adminNotesControllerProvider(_filter)),
        ),
        data: (s) {
          final notes = [
            for (final n in s.notes)
              if (q.isEmpty || n.title.toLowerCase().contains(q)) n,
          ];
          if (notes.isEmpty) {
            return const EmptyView(
              icon: Icons.description_outlined,
              title: AppStrings.nothingHereYet,
              message: AppStrings.addFirstItem,
            );
          }
          return AdminTable<Note>(
            items: notes,
            title: (n) => n.title,
            subtitle: (n) => '${_context(n)} · ${_price(n)}',
            leading: (n) => NoteCover(
              title: n.title,
              thumbnailUrl: n.thumbnailUrl,
              width: 56,
              height: 36,
              borderRadius: 8,
            ),
            columns: [
              AdminColumn(
                '',
                (n) => NoteCover(
                  title: n.title,
                  thumbnailUrl: n.thumbnailUrl,
                  width: 56,
                  height: 36,
                  borderRadius: 8,
                ),
              ),
              AdminColumn(
                AppStrings.fieldTitle,
                (n) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(n.title, overflow: TextOverflow.ellipsis),
                ),
              ),
              AdminColumn(AppStrings.adminSubjects, (n) => Text(_context(n))),
              AdminColumn(AppStrings.fieldPrice, (n) => Text(_price(n))),
              AdminColumn(
                '',
                (n) => Text(
                  n.pageCount == 0 ? '—' : AppStrings.pages(n.pageCount),
                ),
              ),
              AdminColumn('', (n) => _StatusChip(published: n.isPublished)),
            ],
            actions: (n) => editDeleteActions(
              onEdit: () => context.go(RoutePaths.adminNoteEdit(n.id)),
              onDelete: () => _delete(n),
            ),
            footer: s.hasMore
                ? Center(
                    child: OutlinedButton(
                      onPressed: s.loadingMore
                          ? null
                          : () => ref
                                .read(
                                  adminNotesControllerProvider(_filter)
                                      .notifier,
                                )
                                .loadMore(),
                      child: s.loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.loadMore),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  static String _context(Note n) =>
      AppStrings.noteContext(n.universityName, n.semesterNumber, n.subjectName);

  static String _price(Note n) =>
      n.isFree ? AppStrings.free : Money.format(n.price);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(published ? AppStrings.published : AppStrings.draft),
      backgroundColor: published
          ? scheme.secondary
          : scheme.surfaceContainerHigh,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: published ? scheme.onSecondary : scheme.onSurfaceVariant,
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─────────────────────────── Note form ───────────────────────────

/// `/admin/notes/new` (noteId null) and `/admin/notes/:noteId/edit`.
class AdminNoteFormPage extends ConsumerWidget {
  const AdminNoteFormPage({this.noteId, super.key});

  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = noteId;
    if (id == null) return const _NoteForm(existing: null);

    return ref
        .watch(adminNoteForEditProvider(id))
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(adminNoteForEditProvider(id)),
          ),
          data: (data) => data == null
              ? const EmptyView(
                  title: AppStrings.notFoundTitle,
                  message: AppStrings.notFoundMessage,
                )
              : _NoteForm(existing: data),
        );
  }
}

class _NoteForm extends ConsumerStatefulWidget {
  const _NoteForm({required this.existing});

  final NoteForEdit? existing;

  @override
  ConsumerState<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<_NoteForm> {
  final _form = GlobalKey<FormState>();
  late final Note? _note = widget.existing?.note;
  late CatalogSelection _sel =
      widget.existing?.selection ?? const CatalogSelection();
  late final _title = TextEditingController(text: _note?.title);
  late final _desc = TextEditingController(text: _note?.description);
  late final _price = TextEditingController(
    text: _note == null || _note.isFree ? '' : Money.toRupeesText(_note.price),
  );
  late final _tags = TextEditingController(text: _note?.tags.join(', '));
  late bool _isFree = _note?.isFree ?? false;
  late bool _publish = _note?.isPublished ?? false;
  late int _previewPages = _note?.previewPages ?? 3;
  PickedFile? _pdf;
  PickedFile? _thumb;

  bool get _hasPdf => _pdf != null || (_note?.hasPdf ?? false);

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final file = await ref.read(filePickerServiceProvider).pickPdf();
    if (file == null || !mounted) return;
    if (file.bytes.length >= CatalogFilesRepository.maxPdfBytes) {
      showSnack(context, AppStrings.pdfTooLarge);
      return;
    }
    setState(() => _pdf = file);
  }

  Future<void> _pickThumb() async {
    final file = await ref.read(filePickerServiceProvider).pickImage();
    if (file == null || !mounted) return;
    if (file.bytes.length >= CatalogFilesRepository.maxImageBytes) {
      showSnack(context, AppStrings.imageTooLarge);
      return;
    }
    setState(() => _thumb = file);
  }

  String? _validatePrice(String? v) {
    if (_isFree) return null;
    final paise = Money.parseRupees(v ?? '');
    if (paise == null) return AppStrings.invalidPrice;
    if (paise <= 0) return AppStrings.priceMustBePositive;
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(noteFormControllerProvider.notifier)
        .save(
          existing: _note,
          pdf: _pdf,
          thumbnail: _thumb,
          draft: NoteDraft(
            title: _title.text,
            description: _desc.text,
            selection: _sel,
            pricePaise: _isFree ? 0 : Money.parseRupees(_price.text)!,
            isFree: _isFree,
            tags: [
              for (final t in _tags.text.split(','))
                if (t.trim().isNotEmpty) t.trim().toLowerCase(),
            ],
            previewPages: _previewPages,
            publish: _publish && _hasPdf,
          ),
        );
    if (ok) {
      ref.invalidate(adminNotesControllerProvider);
      if (_note != null) ref.invalidate(adminNoteForEditProvider(_note.id));
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
      router.go(RoutePaths.adminNotes);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.noteSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteFormControllerProvider);
    final saving = state.isLoading || state.value != null;
    final text = Theme.of(context).textTheme;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: AppStrings.fieldTitle),
          validator: (v) =>
              (v ?? '').trim().length < 3 ? AppStrings.required : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _desc,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: AppStrings.fieldDescription,
          ),
        ),
        const SizedBox(height: 16),
        CatalogPicker(
          selection: _sel,
          validate: true,
          onChanged: (s) => setState(() => _sel = s),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.fieldFree),
          value: _isFree,
          onChanged: (v) => setState(() => _isFree = v),
        ),
        if (!_isFree)
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.fieldPrice,
              prefixText: '₹ ',
            ),
            validator: _validatePrice,
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tags,
          decoration: const InputDecoration(labelText: AppStrings.fieldTags),
        ),
      ],
    );

    final filesAndPublish = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.fieldThumbnail, style: text.titleMedium),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 5 / 3,
          child: _thumb != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _thumb!.bytes,
                    fit: BoxFit.cover,
                    // A file that isn't a valid image → show the cover.
                    errorBuilder: (_, _, _) => NoteCover(title: _title.text),
                  ),
                )
              : NoteCover(
                  title: _title.text,
                  thumbnailUrl: _note?.thumbnailUrl,
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: saving ? null : _pickThumb,
          icon: const Icon(Icons.image_outlined),
          label: const Text(AppStrings.chooseImage),
        ),
        const SizedBox(height: 24),
        Text(AppStrings.fieldPdf, style: text.titleMedium),
        const SizedBox(height: 8),
        if (_pdf != null)
          Text(
            '${_pdf!.name} · ${(_pdf!.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
          )
        else if (_note?.hasPdf ?? false)
          Text(
            [
              AppStrings.pdfAttached,
              if (_note!.pageCount > 0) AppStrings.pages(_note.pageCount),
            ].join(' · '),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: saving ? null : _pickPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_hasPdf ? AppStrings.replacePdf : AppStrings.choosePdf),
        ),
        if (state.value != null) ...[
          const SizedBox(height: 12),
          Text(AppStrings.uploading, style: text.bodySmall),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: state.value),
        ],
        const SizedBox(height: 24),
        DropdownButtonFormField<int>(
          initialValue: _previewPages,
          decoration: const InputDecoration(
            labelText: AppStrings.fieldPreviewPages,
          ),
          items: [
            for (final n in const [0, 1, 2, 3, 4, 5, 8, 10])
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (n) => setState(() => _previewPages = n!),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.fieldPublished),
          subtitle: _hasPdf ? null : const Text(AppStrings.publishNeedsPdf),
          value: _publish && _hasPdf,
          onChanged: _hasPdf ? (v) => setState(() => _publish = v) : null,
        ),
        const SizedBox(height: 16),
        SubmitButton(
          label: AppStrings.save,
          isLoading: saving,
          onPressed: _save,
        ),
      ],
    );

    return Form(
      key: _form,
      child: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: AppStrings.adminNotes,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(RoutePaths.adminNotes),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _note == null ? AppStrings.newNote : AppStrings.editNote,
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (context.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: details,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: filesAndPublish,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Card(
              child: Padding(padding: const EdgeInsets.all(20), child: details),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: filesAndPublish,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
