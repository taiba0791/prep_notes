import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/catalog.dart';
import '../../../data/models/university.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/note_repository.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/catalog_picker.dart';

// ─────────────────────────── Universities ───────────────────────────

class AdminUniversitiesPage extends ConsumerStatefulWidget {
  const AdminUniversitiesPage({super.key});

  @override
  ConsumerState<AdminUniversitiesPage> createState() =>
      _AdminUniversitiesPageState();
}

class _AdminUniversitiesPageState extends ConsumerState<AdminUniversitiesPage> {
  String _search = '';

  Future<void> _edit([University? u]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UniversityDialog(existing: u),
    );
    if (saved == true) ref.invalidate(adminUniversitiesProvider);
  }

  Future<void> _delete(University u) async {
    if (!await confirmDelete(context, u.name) || !mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref.read(catalogRepositoryProvider).deleteUniversity(u.id),
      success: AppStrings.deleted,
    );
    if (ok) ref.invalidate(adminUniversitiesProvider);
  }

  Future<void> _toggle(University u, bool active) async {
    final ok = await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .setActive(FirestoreCollections.universities, u.id, active: active),
    );
    if (ok) ref.invalidate(adminUniversitiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminUniversitiesProvider);
    final q = _search.toLowerCase();

    return AdminPage(
      title: AppStrings.adminUniversities,
      actions: [
        FilledButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.add),
        ),
      ],
      filters: _SearchField(onChanged: (v) => setState(() => _search = v)),
      child: AsyncListBody<University>(
        value: list,
        onRetry: () => ref.invalidate(adminUniversitiesProvider),
        data: (items) => AdminTable<University>(
          items: [
            for (final u in items)
              if (q.isEmpty ||
                  u.name.toLowerCase().contains(q) ||
                  u.shortName.toLowerCase().contains(q))
                u,
          ],
          title: (u) => u.name,
          subtitle: (u) => [
            u.shortName,
            u.city ?? '',
          ].where((s) => s.isNotEmpty).join(' · '),
          leading: (u) => _Logo(university: u),
          columns: [
            AdminColumn('', (u) => _Logo(university: u)),
            AdminColumn(AppStrings.fieldName, (u) => Text(u.name)),
            AdminColumn(AppStrings.fieldShortName, (u) => Text(u.shortName)),
            AdminColumn(AppStrings.fieldCity, (u) => Text(u.city ?? '')),
            AdminColumn(
              AppStrings.fieldOrder,
              (u) => Text('${u.order}'),
              numeric: true,
            ),
            AdminColumn(
              AppStrings.active,
              (u) => Switch(value: u.isActive, onChanged: (v) => _toggle(u, v)),
            ),
          ],
          actions: (u) => editDeleteActions(
            onEdit: () => _edit(u),
            onDelete: () => _delete(u),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.university});

  final University university;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = university.logoUrl;
    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundImage: url == null ? null : NetworkImage(url),
      // A broken logo link just shows the initials.
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        (university.shortName.isNotEmpty
                ? university.shortName
                : university.name)
            .characters
            .take(3)
            .toString(),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.secondary),
      ),
    );
  }
}

class _UniversityDialog extends ConsumerStatefulWidget {
  const _UniversityDialog({this.existing});

  final University? existing;

  @override
  ConsumerState<_UniversityDialog> createState() => _UniversityDialogState();
}

class _UniversityDialogState extends ConsumerState<_UniversityDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _short = TextEditingController(text: widget.existing?.shortName);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _order = TextEditingController(
    text: '${widget.existing?.order ?? 0}',
  );
  late bool _active = widget.existing?.isActive ?? true;
  PickedFile? _logo;
  bool _saving = false;

  static const _maxLogoBytes = 1024 * 1024;

  @override
  void dispose() {
    for (final c in [_name, _short, _city, _desc, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ref.read(filePickerServiceProvider).pickImage();
    if (file == null || !mounted) return;
    if (file.bytes.length >= _maxLogoBytes) {
      showSnack(context, AppStrings.imageTooLarge);
      return;
    }
    setState(() => _logo = file);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final catalog = ref.read(catalogRepositoryProvider);
    final files = ref.read(catalogFilesRepositoryProvider);
    final ok = await runAdminAction(context, () async {
      var u = University(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        shortName: _short.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        logoUrl: widget.existing?.logoUrl,
        order: int.parse(_order.text.trim()),
        isActive: _active,
      );
      final id = await catalog.saveUniversity(u);
      final logo = _logo;
      if (logo != null) {
        final url = await files.uploadUniversityLogo(
          id,
          logo.bytes,
          logo.contentType,
        );
        u = u.copyWith(id: id, logoUrl: url);
        await catalog.saveUniversity(u);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null
          ? AppStrings.adminUniversities
          : AppStrings.edit,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: AppStrings.fieldName),
          validator: (v) =>
              (v ?? '').trim().length < 2 ? AppStrings.required : null,
        ),
        TextFormField(
          controller: _short,
          decoration: const InputDecoration(
            labelText: AppStrings.fieldShortName,
          ),
        ),
        TextFormField(
          controller: _city,
          decoration: const InputDecoration(labelText: AppStrings.fieldCity),
        ),
        TextFormField(
          controller: _desc,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: AppStrings.fieldDescription,
          ),
        ),
        TextFormField(
          controller: _order,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: AppStrings.fieldOrder),
          validator: intValidator(min: 0, max: 9999),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.image_outlined),
              label: const Text(AppStrings.chooseImage),
            ),
            const SizedBox(width: 12),
            if (_logo != null)
              CircleAvatar(
                radius: 20,
                backgroundImage: MemoryImage(_logo!.bytes),
                onBackgroundImageError: (_, _) {},
              )
            else if (widget.existing?.logoUrl != null)
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(widget.existing!.logoUrl!),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.active),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

// ─────────────────────────── Semesters ───────────────────────────

class AdminSemestersPage extends ConsumerStatefulWidget {
  const AdminSemestersPage({super.key});

  @override
  ConsumerState<AdminSemestersPage> createState() => _AdminSemestersPageState();
}

class _AdminSemestersPageState extends ConsumerState<AdminSemestersPage> {
  CatalogSelection _sel = const CatalogSelection();

  void _reload() => ref.invalidate(adminSemestersProvider(_sel.university!.id));

  Future<void> _edit([Semester? s]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _SemesterDialog(universityId: _sel.university!.id, existing: s),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Semester s) async {
    if (!await confirmDelete(context, s.name) || !mounted) return;
    if (await runAdminAction(
      context,
      () => ref.read(catalogRepositoryProvider).deleteSemester(s.id),
      success: AppStrings.deleted,
    )) {
      _reload();
    }
  }

  Future<void> _toggle(Semester s, bool v) async {
    if (await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .setActive(FirestoreCollections.semesters, s.id, active: v),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _sel.university;
    return AdminPage(
      title: AppStrings.adminSemesters,
      actions: [
        FilledButton.icon(
          onPressed: u == null ? null : _edit,
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.add),
        ),
      ],
      filters: CatalogPicker(
        selection: _sel,
        depth: CatalogDepth.university,
        onChanged: (s) => setState(() => _sel = s),
      ),
      child: u == null
          ? const EmptyView(
              title: AppStrings.pickUniversity,
              message: AppStrings.chooseParentFirst,
            )
          : AsyncListBody<Semester>(
              value: ref.watch(adminSemestersProvider(u.id)),
              onRetry: _reload,
              data: (items) => AdminTable<Semester>(
                items: items,
                title: (s) => s.name,
                subtitle: (s) => '${AppStrings.fieldNumber} ${s.number}',
                columns: [
                  AdminColumn(
                    AppStrings.fieldNumber,
                    (s) => Text('${s.number}'),
                    numeric: true,
                  ),
                  AdminColumn(AppStrings.fieldName, (s) => Text(s.name)),
                  AdminColumn(
                    AppStrings.active,
                    (s) => Switch(
                      value: s.isActive,
                      onChanged: (v) => _toggle(s, v),
                    ),
                  ),
                ],
                actions: (s) => editDeleteActions(
                  onEdit: () => _edit(s),
                  onDelete: () => _delete(s),
                ),
              ),
            ),
    );
  }
}

class _SemesterDialog extends ConsumerStatefulWidget {
  const _SemesterDialog({required this.universityId, this.existing});

  final String universityId;
  final Semester? existing;

  @override
  ConsumerState<_SemesterDialog> createState() => _SemesterDialogState();
}

class _SemesterDialogState extends ConsumerState<_SemesterDialog> {
  final _form = GlobalKey<FormState>();
  late int _number = widget.existing?.number ?? 1;
  late final _name = TextEditingController(
    text: widget.existing?.name ?? AppStrings.semesterLabel(_number),
  );
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .saveSemester(
            Semester(
              id: widget.existing?.id ?? '',
              universityId: widget.universityId,
              number: _number,
              name: _name.text.trim(),
              isActive: _active,
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null
          ? AppStrings.adminSemesters
          : AppStrings.edit,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _number,
          decoration: const InputDecoration(labelText: AppStrings.fieldNumber),
          items: [
            for (var n = 1; n <= 12; n++)
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (n) => setState(() {
            // Keep the default name in step with the number.
            if (_name.text == AppStrings.semesterLabel(_number)) {
              _name.text = AppStrings.semesterLabel(n!);
            }
            _number = n!;
          }),
        ),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: AppStrings.fieldName),
          validator: requiredText,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.active),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

// ─────────────────────────── Subjects ───────────────────────────

class AdminSubjectsPage extends ConsumerStatefulWidget {
  const AdminSubjectsPage({super.key});

  @override
  ConsumerState<AdminSubjectsPage> createState() => _AdminSubjectsPageState();
}

class _AdminSubjectsPageState extends ConsumerState<AdminSubjectsPage> {
  CatalogSelection _sel = const CatalogSelection();

  void _reload() => ref.invalidate(adminSubjectsProvider(_sel.semester!.id));

  Future<void> _edit([Subject? s]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SubjectDialog(
        universityId: _sel.university!.id,
        semesterId: _sel.semester!.id,
        existing: s,
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Subject s) async {
    if (!await confirmDelete(context, s.name) || !mounted) return;
    if (await runAdminAction(
      context,
      () => ref.read(catalogRepositoryProvider).deleteSubject(s.id),
      success: AppStrings.deleted,
    )) {
      _reload();
    }
  }

  Future<void> _toggle(Subject s, bool v) async {
    if (await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .setActive(FirestoreCollections.subjects, s.id, active: v),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = _sel.semester;
    return AdminPage(
      title: AppStrings.adminSubjects,
      actions: [
        FilledButton.icon(
          onPressed: sem == null ? null : _edit,
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.add),
        ),
      ],
      filters: CatalogPicker(
        selection: _sel,
        depth: CatalogDepth.semester,
        onChanged: (s) => setState(() => _sel = s),
      ),
      child: sem == null
          ? const EmptyView(
              title: AppStrings.pickSemester,
              message: AppStrings.chooseParentFirst,
            )
          : AsyncListBody<Subject>(
              value: ref.watch(adminSubjectsProvider(sem.id)),
              onRetry: _reload,
              data: (items) => AdminTable<Subject>(
                items: items,
                title: (s) => s.name,
                subtitle: (s) => s.code,
                columns: [
                  AdminColumn(AppStrings.fieldName, (s) => Text(s.name)),
                  AdminColumn(AppStrings.fieldCode, (s) => Text(s.code)),
                  AdminColumn(
                    AppStrings.active,
                    (s) => Switch(
                      value: s.isActive,
                      onChanged: (v) => _toggle(s, v),
                    ),
                  ),
                ],
                actions: (s) => editDeleteActions(
                  onEdit: () => _edit(s),
                  onDelete: () => _delete(s),
                ),
              ),
            ),
    );
  }
}

class _SubjectDialog extends ConsumerStatefulWidget {
  const _SubjectDialog({
    required this.universityId,
    required this.semesterId,
    this.existing,
  });

  final String universityId;
  final String semesterId;
  final Subject? existing;

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _code, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .saveSubject(
            Subject(
              id: widget.existing?.id ?? '',
              universityId: widget.universityId,
              semesterId: widget.semesterId,
              name: _name.text.trim(),
              code: _code.text.trim(),
              description: _desc.text.trim(),
              isActive: _active,
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null
          ? AppStrings.adminSubjects
          : AppStrings.edit,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: AppStrings.fieldName),
          validator: (v) =>
              (v ?? '').trim().length < 2 ? AppStrings.required : null,
        ),
        TextFormField(
          controller: _code,
          decoration: const InputDecoration(labelText: AppStrings.fieldCode),
        ),
        TextFormField(
          controller: _desc,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: AppStrings.fieldDescription,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.active),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

// ─────────────────────────── Modules ───────────────────────────

class AdminModulesPage extends ConsumerStatefulWidget {
  const AdminModulesPage({super.key});

  @override
  ConsumerState<AdminModulesPage> createState() => _AdminModulesPageState();
}

class _AdminModulesPageState extends ConsumerState<AdminModulesPage> {
  CatalogSelection _sel = const CatalogSelection();

  void _reload() => ref.invalidate(adminModulesProvider(_sel.subject!.id));

  Future<void> _edit([Module? m]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ModuleDialog(subjectId: _sel.subject!.id, existing: m),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Module m) async {
    if (!await confirmDelete(context, m.title) || !mounted) return;
    if (await runAdminAction(
      context,
      () => ref.read(catalogRepositoryProvider).deleteModule(m.id),
      success: AppStrings.deleted,
    )) {
      _reload();
    }
  }

  Future<void> _toggle(Module m, bool v) async {
    if (await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .setActive(FirestoreCollections.modules, m.id, active: v),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _sel.subject;
    return AdminPage(
      title: AppStrings.adminModules,
      actions: [
        FilledButton.icon(
          onPressed: sub == null ? null : _edit,
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.add),
        ),
      ],
      filters: CatalogPicker(
        selection: _sel,
        depth: CatalogDepth.subject,
        onChanged: (s) => setState(() => _sel = s),
      ),
      child: sub == null
          ? const EmptyView(
              title: AppStrings.pickSubject,
              message: AppStrings.chooseParentFirst,
            )
          : AsyncListBody<Module>(
              value: ref.watch(adminModulesProvider(sub.id)),
              onRetry: _reload,
              data: (items) => AdminTable<Module>(
                items: items,
                title: (m) => '${m.number}. ${m.title}',
                columns: [
                  AdminColumn(
                    AppStrings.fieldNumber,
                    (m) => Text('${m.number}'),
                    numeric: true,
                  ),
                  AdminColumn(AppStrings.fieldTitle, (m) => Text(m.title)),
                  AdminColumn(
                    AppStrings.active,
                    (m) => Switch(
                      value: m.isActive,
                      onChanged: (v) => _toggle(m, v),
                    ),
                  ),
                ],
                actions: (m) => editDeleteActions(
                  onEdit: () => _edit(m),
                  onDelete: () => _delete(m),
                ),
              ),
            ),
    );
  }
}

class _ModuleDialog extends ConsumerStatefulWidget {
  const _ModuleDialog({required this.subjectId, this.existing});

  final String subjectId;
  final Module? existing;

  @override
  ConsumerState<_ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends ConsumerState<_ModuleDialog> {
  final _form = GlobalKey<FormState>();
  late final _number = TextEditingController(
    text: '${widget.existing?.number ?? 1}',
  );
  late final _title = TextEditingController(text: widget.existing?.title);
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(catalogRepositoryProvider)
          .saveModule(
            Module(
              id: widget.existing?.id ?? '',
              subjectId: widget.subjectId,
              number: int.parse(_number.text.trim()),
              title: _title.text.trim(),
              isActive: _active,
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.existing == null
          ? AppStrings.adminModules
          : AppStrings.edit,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      children: [
        TextFormField(
          controller: _number,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: AppStrings.fieldNumber),
          validator: intValidator(min: 1, max: 50),
        ),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: AppStrings.fieldTitle),
          validator: requiredText,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.active),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

// ─────────────────────────── Shared ───────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: AppStrings.searchHint,
        prefixIcon: Icon(Icons.search),
      ),
    ),
  );
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in children) ...[c, const SizedBox(height: 12)],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(AppStrings.save),
        ),
      ],
    );
  }
}
