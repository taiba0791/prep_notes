import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../data/repositories/catalog_repository.dart';

/// Header + optional filters + body, used by every admin list page.
class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    this.actions = const [],
    this.filters,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final Widget? filters;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
          if (filters != null) ...[const SizedBox(height: 16), filters!],
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// One column in an [AdminTable].
class AdminColumn<T> {
  const AdminColumn(this.label, this.cell, {this.numeric = false});

  final String label;
  final Widget Function(T item) cell;
  final bool numeric;
}

/// Data table on tablet/desktop, cards on phones (CLAUDE.md: responsive).
class AdminTable<T> extends StatelessWidget {
  const AdminTable({
    required this.items,
    required this.columns,
    required this.title,
    required this.actions,
    this.subtitle,
    this.leading,
    this.footer,
    super.key,
  });

  final List<T> items;
  final List<AdminColumn<T>> columns;
  final String Function(T) title;
  final String Function(T)? subtitle;
  final Widget Function(T)? leading;
  final List<Widget> Function(T) actions;

  /// e.g. a "Load more" button.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length + (footer == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == items.length) return footer!;
          final item = items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!(item),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title(item),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!(item),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  ...actions(item),
                ],
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          // Fill the available width; scroll sideways only if the table
          // really doesn't fit.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingTextStyle: Theme.of(context).textTheme.labelLarge,
                  columns: [
                    for (final c in columns)
                      DataColumn(label: Text(c.label), numeric: c.numeric),
                    const DataColumn(label: Text(AppStrings.actions)),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          for (final c in columns) DataCell(c.cell(item)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions(item),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ],
    );
  }
}

/// Edit / delete icon buttons for a row.
List<Widget> editDeleteActions({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) => [
  IconButton(
    tooltip: AppStrings.edit,
    icon: const Icon(Icons.edit_outlined),
    onPressed: onEdit,
  ),
  IconButton(
    tooltip: AppStrings.delete,
    icon: const Icon(Icons.delete_outline),
    onPressed: onDelete,
  ),
];

/// "Delete X?" confirmation. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppStrings.deleteConfirmTitle(what)),
      content: const Text(AppStrings.deleteConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AppStrings.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

/// Friendly text for errors from catalog writes.
String catalogErrorMessage(Object error) => switch (error) {
  CatalogInUseException(:final childCollection) => AppStrings.inUse(
    switch (childCollection) {
      FirestoreCollections.semesters => 'semesters',
      FirestoreCollections.subjects => 'subjects',
      FirestoreCollections.modules => 'modules',
      FirestoreCollections.notes => 'notes',
      _ => 'items',
    },
  ),
  _ => AppStrings.authErrorUnknown,
};

/// Runs a write, then shows "Saved." / "Deleted." or a friendly error.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  String success = AppStrings.saved,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(catalogErrorMessage(e))));
    return false;
  }
}

/// Active / inactive chip.
class ActiveChip extends StatelessWidget {
  const ActiveChip({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(active ? AppStrings.active : AppStrings.inactive),
      backgroundColor: active
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHigh,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Standard async body: loading / error (+retry) / empty / data.
class AsyncListBody<T> extends StatelessWidget {
  const AsyncListBody({
    required this.value,
    required this.onRetry,
    required this.data,
    super.key,
  });

  final AsyncValue<List<T>> value;
  final VoidCallback onRetry;
  final Widget Function(List<T> items) data;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const LoadingView(),
    error: (_, _) => ErrorView(onRetry: onRetry),
    data: (items) => items.isEmpty
        ? const EmptyView(
            title: AppStrings.nothingHereYet,
            message: AppStrings.addFirstItem,
          )
        : data(items),
  );
}

/// Simple int validator for form fields.
String? Function(String?) intValidator({required int min, required int max}) =>
    (v) {
      final n = int.tryParse(v?.trim() ?? '');
      if (n == null || n < min || n > max) return AppStrings.mustBeNumber;
      return null;
    };

String? requiredText(String? v) =>
    (v == null || v.trim().isEmpty) ? AppStrings.required : null;
