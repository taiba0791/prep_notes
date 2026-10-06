import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/purchase_failure.dart';
import 'purchases_controllers.dart';

/// `/notes/:noteId/view` — the FULL PDF, for owners, free notes and admins.
/// The server decides (getNoteFileUrl); this screen only shows the result.
///
/// Phones: in-app viewer with pinch zoom, page counter and a faint
/// watermark with the reader's email. Web: opens in a browser tab.
class NoteViewerScreen extends ConsumerWidget {
  const NoteViewerScreen({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.pageNoteViewer),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.note(noteId)),
        ),
      ),
      body: kIsWeb ? _WebViewer(noteId: noteId) : _AppViewer(noteId: noteId),
    );
  }
}

/// Error view that explains "buy first" with a link back to the note.
Widget _viewerError(
  BuildContext context,
  Object error,
  String noteId,
  VoidCallback retry,
) {
  final failure = error is PurchaseException ? error.failure : null;
  if (failure == PurchaseFailure.notPurchased ||
      failure == PurchaseFailure.notAvailable) {
    return EmptyView(
      icon: Icons.lock_outline,
      title: failure!.message,
      message: '',
      action: FilledButton(
        onPressed: () => context.go(RoutePaths.note(noteId)),
        child: const Text(AppStrings.buyNow),
      ),
    );
  }
  return ErrorView(message: failure?.message, onRetry: retry);
}

class _WebViewer extends ConsumerWidget {
  const _WebViewer({required this.noteId});

  final String noteId;

  static const _fresh = Duration(minutes: 9);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = noteFileLinkProvider(noteId);
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) =>
              _viewerError(context, e, noteId, () => ref.invalidate(provider)),
          data: (link) => EmptyView(
            icon: Icons.picture_as_pdf_outlined,
            title: AppStrings.viewerOpenPdf,
            message: AppStrings.viewerWebHint,
            action: FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text(AppStrings.viewerOpenPdf),
              onPressed: () {
                if (DateTime.now().difference(link.fetchedAt) > _fresh) {
                  // Expired: get a fresh link (the button reappears).
                  ref.invalidate(provider);
                  return;
                }
                launchUrl(Uri.parse(link.url), webOnlyWindowName: '_blank');
              },
            ),
          ),
        );
  }
}

class _AppViewer extends ConsumerStatefulWidget {
  const _AppViewer({required this.noteId});

  final String noteId;

  @override
  ConsumerState<_AppViewer> createState() => _AppViewerState();
}

class _AppViewerState extends ConsumerState<_AppViewer> {
  PdfControllerPinch? _controller;
  int _page = 1;
  int _pages = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _retry() {
    // A new signed link, then a new download.
    ref.invalidate(noteFileLinkProvider(widget.noteId));
    ref.invalidate(noteFileBytesProvider(widget.noteId));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = ref.watch(viewerWatermarkProvider);
    return ref
        .watch(noteFileBytesProvider(widget.noteId))
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _viewerError(context, e, widget.noteId, _retry),
          data: (bytes) {
            _controller ??= PdfControllerPinch(
              document: PdfDocument.openData(bytes),
            );
            return Stack(
              children: [
                PdfViewPinch(
                  controller: _controller!,
                  onDocumentLoaded: (doc) =>
                      setState(() => _pages = doc.pagesCount),
                  onPageChanged: (page) => setState(() => _page = page),
                ),
                if (email.isNotEmpty)
                  Positioned.fill(child: _Watermark(text: email)),
                if (_pages > 0)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Chip(
                        label: Text(
                          AppStrings.viewerPage(_page, _pages),
                          style: text.labelMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

/// Faint diagonal "PrepNotes · email" — discourages sharing screenshots.
/// Ignores touches so zoom and scroll still work.
class _Watermark extends StatelessWidget {
  const _Watermark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
    );
    return IgnorePointer(
      child: ClipRect(
        // Lets the rotated text be larger than the screen (clipped).
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.rotate(
            angle: -math.pi / 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      AppStrings.watermark(text),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: style,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
