import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/theme_mode_button.dart';
import '../../../data/models/note_query.dart';
import 'browse_providers.dart';

/// Shared page frame for browse screens: app bar on phones, scrollable body.
class _BrowsePage extends StatelessWidget {
  const _BrowsePage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: context.isMobile
          ? AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  tooltip: AppStrings.searchTitle,
                  icon: const Icon(Icons.search),
                  onPressed: () => context.go(RoutePaths.search),
                ),
                const ThemeModeButton(),
              ],
            )
          : null,
      body: ListView(
        children: [
          PageContainer(
            vertical: context.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── /notes ─────────────────────────────────────────────────

class NotesHomeScreen extends ConsumerWidget {
  const NotesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unis = ref.watch(browseUniversitiesProvider);
    return _BrowsePage(
      title: AppStrings.navNotes,
      children: [
        const SectionHeader(
          heading: AccentHeading(
            start: AppStrings.browseByStart,
            accent: AppStrings.browseByAccent,
          ),
        ),
        unis.when(
          loading: () => const SizedBox(height: 120, child: LoadingView()),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(browseUniversitiesProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyView(
                  icon: Icons.account_balance_outlined,
                  title: AppStrings.noNotesYetTitle,
                  message: AppStrings.noNotesYetMessage,
                )
              : ResponsiveGrid(
                  spacing: 16,
                  mobileColumns: 2,
                  children: [
                    for (final u in list) UniversityCard(university: u),
                  ],
                ),
        ),
        const SizedBox(height: 48),
        Text(
          AppStrings.allNotes,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const NotesExplorer(base: NoteQuery()),
      ],
    );
  }
}

// ── /notes/u/:universityId ─────────────────────────────────

class UniversityScreen extends ConsumerWidget {
  const UniversityScreen({required this.universityId, super.key});

  final String universityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uni = ref.watch(universityByIdProvider(universityId));
    return uni.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => Scaffold(
        body: ErrorView(
          onRetry: () => ref.invalidate(universityByIdProvider(universityId)),
        ),
      ),
      data: (u) {
        if (u == null || !u.isActive) return const _NotFound();
        final semesters = ref.watch(activeSemestersProvider(universityId));
        return _BrowsePage(
          title: u.shortName.isNotEmpty ? u.shortName : u.name,
          children: [
            Breadcrumbs(
              items: [(AppStrings.navNotes, RoutePaths.notes), (u.name, null)],
            ),
            Text(u.name, style: Theme.of(context).textTheme.headlineLarge),
            if (u.description != null && u.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                u.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 28),
            Text(
              AppStrings.semestersTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            semesters.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => ErrorView(
                onRetry: () =>
                    ref.invalidate(activeSemestersProvider(universityId)),
              ),
              data: (list) => list.isEmpty
                  ? Text(
                      AppStrings.noNotesYetMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final s in list)
                          ActionChip(
                            avatar: const Icon(
                              Icons.calendar_view_week_outlined,
                              size: 18,
                            ),
                            label: Text(s.name),
                            onPressed: () =>
                                context.go(RoutePaths.semester(s.id)),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
            Text(
              AppStrings.allNotes,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            NotesExplorer(base: NoteQuery(universityId: universityId)),
          ],
        );
      },
    );
  }
}

// ── /notes/s/:semesterId ───────────────────────────────────

class SemesterScreen extends ConsumerWidget {
  const SemesterScreen({required this.semesterId, super.key});

  final String semesterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sem = ref.watch(semesterByIdProvider(semesterId));
    return sem.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => Scaffold(
        body: ErrorView(
          onRetry: () => ref.invalidate(semesterByIdProvider(semesterId)),
        ),
      ),
      data: (s) {
        if (s == null || !s.isActive) return const _NotFound();
        final uni = ref.watch(universityByIdProvider(s.universityId)).value;
        final subjects = ref.watch(activeSubjectsProvider(semesterId));
        final text = Theme.of(context).textTheme;
        return _BrowsePage(
          title: s.name,
          children: [
            Breadcrumbs(
              items: [
                (AppStrings.navNotes, RoutePaths.notes),
                if (uni != null) (uni.name, RoutePaths.university(uni.id)),
                (s.name, null),
              ],
            ),
            Text(s.name, style: text.headlineLarge),
            if (uni != null) Text(uni.name, style: text.bodyLarge),
            const SizedBox(height: 28),
            Text(AppStrings.subjectsTitle, style: text.titleLarge),
            const SizedBox(height: 12),
            subjects.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => ErrorView(
                onRetry: () =>
                    ref.invalidate(activeSubjectsProvider(semesterId)),
              ),
              data: (list) => list.isEmpty
                  ? Text(AppStrings.noNotesYetMessage, style: text.bodyMedium)
                  : ResponsiveGrid(
                      spacing: 16,
                      desktopColumns: 3,
                      children: [
                        for (final sub in list)
                          Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(sub.name, style: text.titleMedium),
                              subtitle: sub.code.isEmpty
                                  ? null
                                  : Text(sub.code),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.go(RoutePaths.subject(sub.id)),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
            Text(AppStrings.allNotes, style: text.headlineSmall),
            const SizedBox(height: 16),
            NotesExplorer(base: NoteQuery(semesterId: semesterId)),
          ],
        );
      },
    );
  }
}

// ── /notes/sub/:subjectId — modules with their notes ───────

class SubjectScreen extends ConsumerWidget {
  const SubjectScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subjectByIdProvider(subjectId));
    return sub.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => Scaffold(
        body: ErrorView(
          onRetry: () => ref.invalidate(subjectByIdProvider(subjectId)),
        ),
      ),
      data: (s) {
        if (s == null || !s.isActive) return const _NotFound();
        final uni = ref.watch(universityByIdProvider(s.universityId)).value;
        final sem = ref.watch(semesterByIdProvider(s.semesterId)).value;
        final modules = ref.watch(activeModulesProvider(subjectId));
        final text = Theme.of(context).textTheme;
        return _BrowsePage(
          title: s.name,
          children: [
            Breadcrumbs(
              items: [
                (AppStrings.navNotes, RoutePaths.notes),
                if (uni != null) (uni.name, RoutePaths.university(uni.id)),
                if (sem != null) (sem.name, RoutePaths.semester(sem.id)),
                (s.name, null),
              ],
            ),
            Text(s.name, style: text.headlineLarge),
            if (s.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.description, style: text.bodyLarge),
            ],
            const SizedBox(height: 28),
            modules.when(
              loading: () => const NoteGridSkeleton(),
              error: (_, _) => ErrorView(
                onRetry: () => ref.invalidate(activeModulesProvider(subjectId)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyView(
                      icon: Icons.view_module_outlined,
                      title: AppStrings.noNotesYetTitle,
                      message: AppStrings.noNotesYetMessage,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final m in list) ...[
                          Text(
                            AppStrings.moduleHeading(m.number, m.title),
                            style: text.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ModuleNotes(moduleId: m.id),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ModuleNotes extends ConsumerWidget {
  const _ModuleNotes({required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(moduleNotesProvider(moduleId))
        .when(
          loading: () => const NoteGridSkeleton(count: 2),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(moduleNotesProvider(moduleId)),
          ),
          data: (notes) => notes.isEmpty
              ? Text(
                  AppStrings.noNotesInModule,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : ResponsiveGrid(
                  children: [for (final n in notes) NoteCard(note: n)],
                ),
        );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: context.isMobile ? AppBar() : null,
    body: EmptyView(
      icon: Icons.search_off,
      title: AppStrings.notFoundTitle,
      message: AppStrings.notFoundMessage,
      action: FilledButton(
        onPressed: () => context.go(RoutePaths.notes),
        child: const Text(AppStrings.browseAllNotes),
      ),
    ),
  );
}

// ── Filters + paginated notes grid ─────────────────────────

/// Free / Paid, max price and sort, over a [base] place in the catalog.
class NotesExplorer extends ConsumerStatefulWidget {
  const NotesExplorer({required this.base, super.key});

  final NoteQuery base;

  @override
  ConsumerState<NotesExplorer> createState() => _NotesExplorerState();
}

class _NotesExplorerState extends ConsumerState<NotesExplorer> {
  late NoteQuery _query = widget.base;

  static const _maxPrices = [4900, 9900, 19900, 49900];

  void _set(NoteQuery q) => setState(() => _query = q);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteExplorerProvider(_query));
    final text = Theme.of(context).textTheme;

    final filters = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<PriceFilter>(
          segments: const [
            ButtonSegment(
              value: PriceFilter.any,
              label: Text(AppStrings.filterAll),
            ),
            ButtonSegment(
              value: PriceFilter.free,
              label: Text(AppStrings.filterFree),
            ),
            ButtonSegment(
              value: PriceFilter.paid,
              label: Text(AppStrings.filterPaid),
            ),
          ],
          selected: {_query.priceFilter},
          onSelectionChanged: (v) => _set(
            _query.copyWith(
              priceFilter: v.first,
              maxPrice: v.first == PriceFilter.free ? null : _query.maxPrice,
            ),
          ),
        ),
        if (_query.priceFilter != PriceFilter.free)
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int?>(
              initialValue: _query.maxPrice,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: AppStrings.maxPriceLabel,
              ),
              items: [
                const DropdownMenuItem<int?>(child: Text(AppStrings.anyPrice)),
                for (final p in _maxPrices)
                  DropdownMenuItem<int?>(
                    value: p,
                    child: Text(AppStrings.upTo(Money.format(p))),
                  ),
              ],
              onChanged: (v) => _set(_query.copyWith(maxPrice: v)),
            ),
          ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<NoteSort>(
            key: ValueKey(_query.effectiveSort),
            initialValue: _query.effectiveSort,
            isExpanded: true,
            decoration: const InputDecoration(labelText: AppStrings.sortLabel),
            items: [
              for (final (s, label) in const [
                (NoteSort.newest, AppStrings.sortNewest),
                (NoteSort.popular, AppStrings.sortPopular),
                (NoteSort.priceLow, AppStrings.sortPriceLow),
                (NoteSort.priceHigh, AppStrings.sortPriceHigh),
              ])
                DropdownMenuItem(value: s, child: Text(label)),
            ],
            onChanged: (s) => _set(_query.copyWith(sort: s!)),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filters,
        if (_query.hasPriceRange && _query.priceFilter != PriceFilter.free) ...[
          const SizedBox(height: 8),
          Text(AppStrings.priceSortNote, style: text.bodySmall),
        ],
        const SizedBox(height: 20),
        state.when(
          loading: () => const NoteGridSkeleton(),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(noteExplorerProvider(_query)),
          ),
          data: (s) => s.notes.isEmpty
              ? const EmptyView(
                  icon: Icons.filter_alt_off_outlined,
                  title: AppStrings.noMatchTitle,
                  message: AppStrings.noMatchMessage,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResponsiveGrid(
                      children: [for (final n in s.notes) NoteCard(note: n)],
                    ),
                    if (s.hasMore) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: OutlinedButton(
                          onPressed: s.loadingMore
                              ? null
                              : () => ref
                                    .read(noteExplorerProvider(_query).notifier)
                                    .loadMore(),
                          child: s.loadingMore
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(AppStrings.loadMore),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
