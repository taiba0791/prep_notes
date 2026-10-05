import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/catalog.dart';
import '../../../../data/models/university.dart';
import '../../../../data/repositories/catalog_repository.dart';

/// What is chosen in a [CatalogPicker]. Choosing a parent clears children.
@immutable
class CatalogSelection {
  const CatalogSelection({
    this.university,
    this.semester,
    this.subject,
    this.module,
  });

  final University? university;
  final Semester? semester;
  final Subject? subject;
  final Module? module;

  CatalogSelection withUniversity(University? u) =>
      CatalogSelection(university: u);
  CatalogSelection withSemester(Semester? s) =>
      CatalogSelection(university: university, semester: s);
  CatalogSelection withSubject(Subject? s) =>
      CatalogSelection(university: university, semester: semester, subject: s);
  CatalogSelection withModule(Module? m) => CatalogSelection(
    university: university,
    semester: semester,
    subject: subject,
    module: m,
  );
}

/// How deep the cascade goes.
enum CatalogDepth { university, semester, subject, module }

/// Cascading dropdowns: University → Semester → Subject → Module.
/// Each list loads only after its parent is chosen.
class CatalogPicker extends ConsumerWidget {
  const CatalogPicker({
    required this.selection,
    required this.onChanged,
    this.depth = CatalogDepth.module,
    this.allowAll = false,
    this.validate = false,
    super.key,
  });

  final CatalogSelection selection;
  final ValueChanged<CatalogSelection> onChanged;
  final CatalogDepth depth;

  /// Filters: each dropdown has an "All" option (= null).
  final bool allowAll;

  /// Forms: every level is required.
  final bool validate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = selection.university;
    final s = selection.semester;
    final sub = selection.subject;

    final fields = <Widget>[
      _Dropdown<University>(
        label: AppStrings.pickUniversity,
        items: ref.watch(adminUniversitiesProvider),
        selectedId: u?.id,
        idOf: (x) => x.id,
        labelOf: (x) => x.name,
        allowAll: allowAll,
        validate: validate,
        onChanged: (x) => onChanged(selection.withUniversity(x)),
      ),
      if (depth.index >= CatalogDepth.semester.index && u != null)
        _Dropdown<Semester>(
          label: AppStrings.pickSemester,
          items: ref.watch(adminSemestersProvider(u.id)),
          selectedId: s?.id,
          idOf: (x) => x.id,
          labelOf: (x) => x.name,
          allowAll: allowAll,
          validate: validate,
          onChanged: (x) => onChanged(selection.withSemester(x)),
        ),
      if (depth.index >= CatalogDepth.subject.index && s != null)
        _Dropdown<Subject>(
          label: AppStrings.pickSubject,
          items: ref.watch(adminSubjectsProvider(s.id)),
          selectedId: sub?.id,
          idOf: (x) => x.id,
          labelOf: (x) => x.name,
          allowAll: allowAll,
          validate: validate,
          onChanged: (x) => onChanged(selection.withSubject(x)),
        ),
      if (depth.index >= CatalogDepth.module.index && sub != null)
        _Dropdown<Module>(
          label: AppStrings.pickModule,
          items: ref.watch(adminModulesProvider(sub.id)),
          selectedId: selection.module?.id,
          idOf: (x) => x.id,
          labelOf: (x) => '${x.number}. ${x.title}',
          allowAll: allowAll,
          validate: validate,
          onChanged: (x) => onChanged(selection.withModule(x)),
        ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (final f in fields) SizedBox(width: 260, child: f)],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.labelOf,
    required this.allowAll,
    required this.validate,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<T>> items;
  final String? selectedId;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final bool allowAll;
  final bool validate;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(labelText: label);
    return items.when(
      loading: () => InputDecorator(
        decoration: decoration,
        child: const LinearProgressIndicator(),
      ),
      error: (_, _) => InputDecorator(
        decoration: decoration.copyWith(errorText: AppStrings.errorTitle),
        child: const SizedBox.shrink(),
      ),
      data: (list) {
        final current = list.any((x) => idOf(x) == selectedId)
            ? selectedId
            : null;
        return DropdownButtonFormField<String?>(
          // Rebuild when the selection is reset from outside.
          key: ValueKey('$label:$current:${list.length}'),
          initialValue: current,
          isExpanded: true,
          decoration: decoration,
          validator: validate
              ? (v) => v == null ? AppStrings.required : null
              : null,
          items: [
            if (allowAll)
              const DropdownMenuItem<String?>(
                child: Text(AppStrings.anyOption),
              ),
            for (final x in list)
              DropdownMenuItem<String?>(
                value: idOf(x),
                child: Text(labelOf(x), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => onChanged(
            id == null ? null : list.firstWhere((x) => idOf(x) == id),
          ),
        );
      },
    );
  }
}
