import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/theme_mode_button.dart';
import '../../../data/models/note.dart';
import '../../auth/data/auth_repository.dart';
import '../../notes/presentation/browse_providers.dart';

/// Home page, following the PrepNotes homepage design:
/// hero · teal stats band · browse by university · popular notes ·
/// why PrepNotes · Study Zone / Resource Room tiles · call to action · footer.
/// (Testimonials are left out until there are real ones.)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sand = context.appColors.cream;
    final gap = context.responsive<double>(mobile: 48, tablet: 64, desktop: 72);

    return Scaffold(
      appBar: context.isMobile
          ? AppBar(
              title: const AppLogo(),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(catalogCountsProvider)
            ..invalidate(popularNotesProvider)
            ..invalidate(browseUniversitiesProvider);
        },
        child: ListView(
          children: [
            PageContainer(vertical: gap * 0.75, child: const _Hero()),
            const _StatsBand(),
            PageContainer(vertical: gap, child: const _Universities()),
            ColoredBox(
              color: sand.withValues(alpha: 0.6),
              child: PageContainer(vertical: gap, child: const _PopularNotes()),
            ),
            PageContainer(vertical: gap, child: const _WhyPrepNotes()),
            ColoredBox(
              color: sand.withValues(alpha: 0.6),
              child: PageContainer(vertical: gap, child: const _Tiles()),
            ),
            ColoredBox(
              color: scheme.surface,
              child: PageContainer(vertical: gap, child: const _CallToAction()),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

// ── 1. Hero ────────────────────────────────────────────────

class _Hero extends ConsumerStatefulWidget {
  const _Hero();

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go([String? text]) {
    final q = (text ?? _search.text).trim();
    context.go(RoutePaths.searchFor(q));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // "Popular" chips = subjects of the popular notes (real data only).
    final subjects = <String>{
      for (final n in ref.watch(popularNotesProvider).value ?? const <Note>[])
        if (n.subjectName.isNotEmpty) n.subjectName,
    }.take(4).toList();

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccentHeading(
          start: AppStrings.heroTitleStart,
          accent: AppStrings.heroTitleAccent,
          end: AppStrings.heroTitleEnd,
          style: context.isMobile ? text.headlineLarge : text.displayMedium,
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(AppStrings.heroSubtitle, style: text.bodyLarge),
        ),
        const SizedBox(height: 26),
        _SearchBar(controller: _search, onSubmit: _go),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(AppStrings.popularLabel, style: text.bodySmall),
              for (final s in subjects)
                ActionChip(label: Text(s), onPressed: () => _go(s)),
            ],
          ),
        ],
      ],
    );

    if (context.isMobile) return copy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: copy),
        const SizedBox(width: 48),
        const Expanded(flex: 10, child: _HeroArch()),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final void Function([String?]) onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSubmit(),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchPlaceholder,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18),
                  ),
                ),
              ),
              FilledButton(
                onPressed: onSubmit,
                child: const Text(AppStrings.searchButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's sand arch with a teal circle, two tilted notes and a
/// "Preview free" badge. Drawn with widgets (no image needed).
class _HeroArch extends StatelessWidget {
  const _HeroArch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget note(Color header, double angle, {bool ring = false}) =>
        Transform.rotate(
          angle: angle,
          child: Container(
            width: 150,
            height: 190,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: header,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                for (final w in [100.0, 118.0, 80.0])
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 0, 12),
                    width: w,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                if (ring)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 8),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

    return Semantics(
      image: true,
      label: AppStrings.previewFreeBadge,
      child: AspectRatio(
        aspectRatio: 1 / 1.02,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.appColors.cream,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(260),
              bottom: Radius.circular(24),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  Positioned(
                    left: w * 0.5 - w * 0.215,
                    top: c.maxHeight * 0.515 - w * 0.215,
                    child: Container(
                      width: w * 0.43,
                      height: w * 0.43,
                      decoration: BoxDecoration(
                        color: scheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.17,
                    top: c.maxHeight * 0.37,
                    child: note(scheme.primary, -8 * math.pi / 180),
                  ),
                  Positioned(
                    left: w * 0.51,
                    top: c.maxHeight * 0.29,
                    child: note(
                      scheme.secondary,
                      7 * math.pi / 180,
                      ring: true,
                    ),
                  ),
                  Positioned(
                    left: w * 0.1,
                    top: c.maxHeight * 0.12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: scheme.secondary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppStrings.previewFreeBadge,
                              style: text.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── 2. Teal stats band (real counts only) ──────────────────

class _StatsBand extends ConsumerWidget {
  const _StatsBand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(catalogCountsProvider).value;
    // Nothing to show until there's real data.
    if (counts == null || counts.notes == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = [
      (counts.notes, AppStrings.statNotes),
      (counts.universities, AppStrings.statUniversities),
      (counts.subjects, AppStrings.statSubjects),
    ];
    return ColoredBox(
      color: scheme.secondary,
      child: PageContainer(
        vertical: 36,
        child: Row(
          children: [
            for (final (n, label) in items)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$n',
                      style: text.displaySmall?.copyWith(
                        color: scheme.onSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label.toUpperCase(),
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 3. Browse by university ────────────────────────────────

class _Universities extends ConsumerWidget {
  const _Universities();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unis = ref.watch(browseUniversitiesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          heading: const AccentHeading(
            start: AppStrings.browseByStart,
            accent: AppStrings.browseByAccent,
          ),
          linkLabel: AppStrings.seeAllUniversities,
          onLink: () => context.go(RoutePaths.notes),
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
                    for (final u in list.take(4)) UniversityCard(university: u),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── 4. Popular this week ───────────────────────────────────

class _PopularNotes extends ConsumerWidget {
  const _PopularNotes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(popularNotesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          heading: const AccentHeading(
            start: AppStrings.popularStart,
            accent: AppStrings.popularAccent,
          ),
          linkLabel: AppStrings.browseAllNotes,
          onLink: () => context.go(RoutePaths.notes),
        ),
        notes.when(
          loading: () => const NoteGridSkeleton(),
          error: (_, _) =>
              ErrorView(onRetry: () => ref.invalidate(popularNotesProvider)),
          data: (list) => list.isEmpty
              ? const EmptyView(
                  icon: Icons.menu_book_outlined,
                  title: AppStrings.noNotesYetTitle,
                  message: AppStrings.noNotesYetMessage,
                )
              : ResponsiveGrid(
                  children: [for (final n in list) NoteCard(note: n)],
                ),
        ),
      ],
    );
  }
}

// ── 5. Why PrepNotes ───────────────────────────────────────

class _WhyPrepNotes extends StatelessWidget {
  const _WhyPrepNotes();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final points = [
      (AppStrings.why1Title, AppStrings.why1Body),
      (AppStrings.why2Title, AppStrings.why2Body),
      (AppStrings.why3Title, AppStrings.why3Body),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          heading: AccentHeading(
            start: AppStrings.whyStart,
            accent: AppStrings.whyAccent,
          ),
        ),
        ResponsiveGrid(
          desktopColumns: 3,
          tabletColumns: 3,
          children: [
            for (final (title, body) in points)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: context.appColors.cream,
                        child: CircleAvatar(
                          radius: 7,
                          backgroundColor: scheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text(body, style: text.bodyMedium),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── 6. Study Zone / Resource Room tiles ────────────────────

class _Tiles extends StatelessWidget {
  const _Tiles();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = [
      (
        AppStrings.studyTileTitle,
        AppStrings.studyTileBody,
        AppStrings.studyTileButton,
        RoutePaths.studyZone,
        scheme.secondary,
        scheme.onSecondary,
        Icons.timer_outlined,
      ),
      (
        AppStrings.resourceTileTitle,
        AppStrings.resourceTileBody,
        AppStrings.resourceTileButton,
        RoutePaths.resources,
        scheme.primary,
        scheme.onPrimary,
        Icons.folder_open_outlined,
      ),
    ];
    return ResponsiveGrid(
      desktopColumns: 2,
      tabletColumns: 2,
      children: [
        for (final (title, body, button, path, bg, fg, icon) in tiles)
          Container(
            constraints: const BoxConstraints(minHeight: 240),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    icon,
                    size: 200,
                    color: fg.withValues(alpha: 0.18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: fg),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Text(
                          body,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: fg.withValues(alpha: 0.92)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: fg,
                          side: BorderSide(color: fg, width: 1.5),
                        ),
                        onPressed: () => context.go(path),
                        child: Text(button),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 7. Call to action ──────────────────────────────────────

class _CallToAction extends ConsumerWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final signedIn = ref.watch(authSessionProvider).value?.isSignedIn ?? false;
    return Column(
      children: [
        Text(
          AppStrings.ctaTitle,
          style: text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (!signedIn)
          Text(
            AppStrings.ctaSubtitle,
            style: text.bodyLarge,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!signedIn)
              FilledButton(
                onPressed: () => context.go(RoutePaths.register),
                child: const Text(AppStrings.signUpFree),
              ),
            OutlinedButton(
              onPressed: () => context.go(RoutePaths.notes),
              child: const Text(AppStrings.browseAllNotes),
            ),
          ],
        ),
      ],
    );
  }
}
