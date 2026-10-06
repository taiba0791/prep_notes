import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/repositories/browse_repository.dart';
import 'browse_providers.dart';

part 'preview_and_search_screens.g.dart';

@riverpod
Future<Uint8List?> previewBytes(Ref ref, String noteId) =>
    ref.watch(browseRepositoryProvider).previewBytes(noteId);

/// `/notes/:noteId/preview` — the FREE preview pages only (the full PDF is
/// private). Phones: in-app viewer with pinch zoom. Web: opens in a browser
/// tab (the browser's PDF viewer).
class NotePreviewScreen extends ConsumerWidget {
  const NotePreviewScreen({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.previewTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.note(noteId)),
        ),
      ),
      body: kIsWeb ? _WebPreview(noteId: noteId) : _AppPreview(noteId: noteId),
    );
  }
}

class _WebPreview extends ConsumerWidget {
  const _WebPreview({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(previewUrlProvider(noteId))
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(previewUrlProvider(noteId)),
          ),
          data: (url) => url == null
              ? const EmptyView(
                  icon: Icons.visibility_off_outlined,
                  title: AppStrings.noPreview,
                  message: '',
                )
              : EmptyView(
                  icon: Icons.picture_as_pdf_outlined,
                  title: AppStrings.previewTitle,
                  message: '',
                  action: FilledButton(
                    onPressed: () =>
                        launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
                    child: const Text(AppStrings.openPreview),
                  ),
                ),
        );
  }
}

class _AppPreview extends ConsumerStatefulWidget {
  const _AppPreview({required this.noteId});

  final String noteId;

  @override
  ConsumerState<_AppPreview> createState() => _AppPreviewState();
}

class _AppPreviewState extends ConsumerState<_AppPreview> {
  PdfControllerPinch? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(previewBytesProvider(widget.noteId))
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(
            onRetry: () => ref.invalidate(previewBytesProvider(widget.noteId)),
          ),
          data: (bytes) {
            if (bytes == null) {
              return const EmptyView(
                icon: Icons.visibility_off_outlined,
                title: AppStrings.noPreview,
                message: '',
              );
            }
            _controller ??= PdfControllerPinch(
              document: PdfDocument.openData(bytes),
            );
            return PdfViewPinch(controller: _controller!);
          },
        );
  }
}

/// `/search?q=…`
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _field = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery.trim();

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery) {
      _field.text = widget.initialQuery;
      _query = widget.initialQuery.trim();
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _field.text.trim();
    setState(() => _query = q);
    // Keep the URL shareable: /search?q=...
    context.go(RoutePaths.searchFor(q));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = ref.watch(searchResultsProvider(_query));

    final body = _query.isEmpty
        ? const EmptyView(
            icon: Icons.search,
            title: AppStrings.searchStartTitle,
            message: AppStrings.searchStartMessage,
          )
        : results.when(
            loading: () => const NoteGridSkeleton(),
            error: (_, _) => ErrorView(
              onRetry: () => ref.invalidate(searchResultsProvider(_query)),
            ),
            data: (notes) => notes.isEmpty
                ? EmptyView(
                    icon: Icons.search_off,
                    title: AppStrings.searchNoResults(_query),
                    message: AppStrings.searchNoResultsHint,
                    action: OutlinedButton(
                      onPressed: () => context.go(RoutePaths.notes),
                      child: const Text(AppStrings.browseAllNotes),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppStrings.resultsFor(_query),
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ResponsiveGrid(
                        children: [for (final n in notes) NoteCard(note: n)],
                      ),
                    ],
                  ),
          );

    return Scaffold(
      appBar: context.isMobile
          ? AppBar(title: const Text(AppStrings.searchTitle))
          : null,
      body: ListView(
        children: [
          PageContainer(
            vertical: context.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _field,
                  autofocus: widget.initialQuery.isEmpty,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: AppStrings.searchButton,
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _submit,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
