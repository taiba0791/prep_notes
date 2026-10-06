import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../../../core/widgets/note_cover.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/access.dart';
import '../../../data/models/note.dart';
import '../../../data/models/recently_viewed.dart';
import '../../../data/repositories/library_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../purchases/data/payment_service.dart';
import '../../purchases/presentation/checkout_screen.dart';
import 'browse_providers.dart';

final _day = DateFormat('d MMM yyyy');

/// Opens the free preview: a new browser tab on web, the in-app viewer on
/// phones.
Future<void> openNotePreview(
  BuildContext context,
  WidgetRef ref,
  String noteId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final url = await ref.read(previewUrlProvider(noteId).future);
  if (url == null) {
    messenger.showSnackBar(const SnackBar(content: Text(AppStrings.noPreview)));
    return;
  }
  if (kIsWeb) {
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  } else {
    await router.push(RoutePaths.notePreview(noteId));
  }
}

/// `/notes/:noteId` — the design's "Note details" screen.
class NoteDetailsScreen extends ConsumerStatefulWidget {
  const NoteDetailsScreen({required this.noteId, super.key});

  final String noteId;

  @override
  ConsumerState<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends ConsumerState<NoteDetailsScreen> {
  bool _recorded = false;

  /// Adds the note to the signed-in user's "Recently viewed" (once), as
  /// soon as both the note and the login are known — the login can arrive
  /// after the note (e.g. right after a page refresh).
  void _maybeRecordView(Note? note, String? uid) {
    if (_recorded || note == null || uid == null) return;
    _recorded = true;
    final library = ref.read(libraryRepositoryProvider);
    final reporter = ref.read(errorReporterProvider);
    library
        .recordView(uid, RecentlyViewed.fromNote(note))
        .then((_) {
          if (mounted) ref.invalidate(recentlyViewedProvider);
        })
        .catchError((Object e, StackTrace st) => reporter.recordError(e, st));
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(noteDetailsProvider(widget.noteId));
    final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
    // After this frame: recording writes to Firestore and refreshes a provider.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeRecordView(note.value, uid),
    );

    return Scaffold(
      appBar: context.isMobile ? AppBar() : null,
      body: note.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(noteDetailsProvider(widget.noteId)),
        ),
        data: (n) => n == null
            ? EmptyView(
                icon: Icons.search_off,
                title: AppStrings.noteNotFoundTitle,
                message: AppStrings.noteNotFoundMessage,
                action: FilledButton(
                  onPressed: () => context.go(RoutePaths.notes),
                  child: const Text(AppStrings.browseAllNotes),
                ),
              )
            : _Details(note: n),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final crumbs = Breadcrumbs(
      items: [
        (AppStrings.navNotes, RoutePaths.notes),
        if (note.universityName.isNotEmpty)
          (note.universityName, RoutePaths.university(note.universityId)),
        if (note.semesterNumber > 0)
          (
            AppStrings.semesterShort(note.semesterNumber),
            RoutePaths.semester(note.semesterId),
          ),
        if (note.subjectName.isNotEmpty)
          (note.subjectName, RoutePaths.subject(note.subjectId)),
        if (note.moduleTitle.isNotEmpty) (note.moduleTitle, null),
      ],
    );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 600 / 340,
          child: NoteCover(
            title: note.title,
            thumbnailUrl: note.thumbnailUrl,
            borderRadius: AppTheme.radiusLarge,
          ),
        ),
        const SizedBox(height: 22),
        Text(AppStrings.freePreview, style: text.titleLarge),
        const SizedBox(height: 10),
        _PreviewTiles(note: note),
        if (note.description.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(note.description, style: text.bodyLarge),
        ],
      ],
    );

    final buy = _BuyCard(note: note);

    return ListView(
      children: [
        PageContainer(
          vertical: context.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              crumbs,
              if (context.isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 12, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 10, child: buy),
                  ],
                )
              else ...[
                buy,
                const SizedBox(height: 24),
                left,
              ],
              const SizedBox(height: 48),
              _Related(note: note),
            ],
          ),
        ),
      ],
    );
  }
}

/// Up to 3 preview page tiles (tap to open the preview) + 3 locked tiles.
class _PreviewTiles extends ConsumerWidget {
  const _PreviewTiles({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preview = note.hasPreview ? note.previewPages.clamp(0, 3) : 0;

    Widget page(int n) => InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openNotePreview(context, ref, note.id),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in [1.0, 0.8, 1.0, 0.6])
              FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const Spacer(),
            Text('${n + 1}', style: text.labelSmall),
          ],
        ),
      ),
    );

    Widget locked() => Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.appColors.cream,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: scheme.secondary, size: 18),
          const SizedBox(height: 4),
          Text(
            AppStrings.buyToUnlock,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (preview == 0) {
      return Text(AppStrings.noPreview, style: text.bodyMedium);
    }
    final tiles = [
      for (var i = 0; i < preview; i++) page(i),
      for (var i = 0; i < 3; i++) locked(),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3 / 4,
      children: tiles,
    );
  }
}

class _BuyCard extends ConsumerWidget {
  const _BuyCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final access = ref.watch(noteAccessProvider(note.id)).value;
    final owned = access?.canRead ?? false;

    final meta = [
      if (note.pageCount > 0) AppStrings.pages(note.pageCount),
      AppStrings.pdfLabel,
      if (note.fileSizeBytes > 0)
        AppStrings.fileSize(note.fileSizeBytes / (1024 * 1024)),
      if (note.purchaseCount > 0) AppStrings.boughtBy(note.purchaseCount),
    ].join(' · ');
    final tag = [
      if (note.universityName.isNotEmpty) note.universityName,
      if (note.semesterNumber > 0) 'Sem ${note.semesterNumber}',
    ].join(' · ');

    final buyInApp = ref.watch(buyInAppProvider);
    void read() => context.push(RoutePaths.noteViewer(note.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tag.isNotEmpty)
              Align(alignment: Alignment.centerLeft, child: InfoPill(tag)),
            const SizedBox(height: 12),
            Text(note.title, style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(meta, style: text.bodyMedium),
            const SizedBox(height: 8),
            PriceTag(
              price: note.price,
              isFree: note.isFree,
              style: text.displaySmall,
            ),
            const SizedBox(height: 16),
            if (owned) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: context.appColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      access!.kind == NoteAccessKind.bundle
                          ? AppStrings.includedInBundle(
                              _day.format(access.until!),
                            )
                          : accessUntilText(access.until),
                      style: text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: read,
                child: const Text(AppStrings.readNow),
              ),
            ] else if (note.isFree)
              FilledButton(
                onPressed: read,
                child: const Text(AppStrings.readFree),
              )
            else if (buyInApp)
              FilledButton(
                onPressed: () => context.push(RoutePaths.checkout(note.id)),
                child: const Text(
                  '${AppStrings.buyNow} · ${AppStrings.accessSixMonths}',
                ),
              )
            else
              BuyOnWebsiteButton(noteId: note.id),
            if (note.hasPreview) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => openNotePreview(context, ref, note.id),
                child: const Text(AppStrings.readPreview),
              ),
            ],
            const SizedBox(height: 16),
            for (final b in const [
              AppStrings.benefitSyllabus,
              AppStrings.benefitPreview,
              AppStrings.benefitDevices,
              AppStrings.benefitCheckout,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: scheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Related extends ConsumerWidget {
  const _Related({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedNotesProvider(note.id)).value ?? const [];
    if (related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          heading: AccentHeading(
            start: AppStrings.moreFromStart,
            accent: note.subjectName.isNotEmpty
                ? note.subjectName
                : AppStrings.semesterShort(note.semesterNumber),
          ),
        ),
        ResponsiveGrid(children: [for (final n in related) NoteCard(note: n)]),
      ],
    );
  }
}
