import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/access.dart';
import '../../../data/repositories/room_repository.dart';
import '../domain/room_links.dart';
import 'embedded_page.dart';
import 'room_providers.dart';

/// `/resources/item/:itemId` — opens a saved item INSIDE PrepNotes (so the
/// student never has to leave during focus mode): YouTube player, Drive
/// preview, or the PDF / photo they uploaded.
class RoomItemScreen extends ConsumerWidget {
  const RoomItemScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(roomItemProvider(itemId));
    final value = item.value;
    final external = value?.url;
    return Scaffold(
      appBar: AppBar(
        title: Text(value?.title ?? AppStrings.roomTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.resources),
        ),
        actions: [
          if (external != null)
            IconButton(
              tooltip: value!.type == RoomItemType.youtube
                  ? AppStrings.openOnYoutube
                  : AppStrings.openInDrive,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(external),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
      body: item.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(roomItemProvider(itemId))),
        data: (i) => i == null
            ? const EmptyView(
                icon: Icons.inventory_2_outlined,
                title: AppStrings.roomItemNotFound,
                message: '',
              )
            : switch (i.type) {
                RoomItemType.youtube => _Youtube(item: i),
                RoomItemType.drive => _Drive(item: i),
                _ => _File(item: i),
              },
      ),
    );
  }
}

class _Youtube extends StatefulWidget {
  const _Youtube({required this.item});

  final RoomItem item;

  @override
  State<_Youtube> createState() => _YoutubeState();
}

class _YoutubeState extends State<_Youtube> {
  late final RoomLink? _link = RoomLink.parse(widget.item.url ?? '');
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final id = _link?.id;
    if (id != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c != null) {
      return Center(
        child: YoutubePlayer(controller: c, aspectRatio: 16 / 9),
      );
    }
    // A playlist: YouTube's embedded playlist player.
    final list = Uri.tryParse(widget.item.url ?? '')?.queryParameters['list'];
    if (list != null) {
      return EmbeddedPage(
        url: 'https://www.youtube.com/embed/videoseries?list=$list',
      );
    }
    // A channel or other page: can only open on YouTube.
    return EmptyView(
      icon: Icons.smart_display_outlined,
      title: widget.item.title,
      message: '',
      action: FilledButton(
        onPressed: () => launchUrl(
          Uri.parse(widget.item.url!),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text(AppStrings.openOnYoutube),
      ),
    );
  }
}

class _Drive extends StatelessWidget {
  const _Drive({required this.item});

  final RoomItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              AppStrings.driveNeedsSharing,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: EmbeddedPage(url: RoomLink.drivePreviewUrl(item.url ?? '')),
        ),
      ],
    );
  }
}

/// Uploaded PDF / photo.
class _File extends ConsumerStatefulWidget {
  const _File({required this.item});

  final RoomItem item;

  @override
  ConsumerState<_File> createState() => _FileState();
}

class _FileState extends ConsumerState<_File> {
  late final Future<Object> _load = kIsWeb
      // Website: a link (the browser shows PDFs / photos itself).
      ? ref.read(roomRepositoryProvider).fileUrl(widget.item)
      // Phones: the bytes, shown in-app.
      : ref.read(roomRepositoryProvider).fileBytes(widget.item);
  PdfControllerPinch? _pdf;

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FutureBuilder<Object>(
      future: _load,
      builder: (context, snap) {
        if (snap.hasError) {
          return const ErrorView(message: AppStrings.roomNotOpen);
        }
        final data = snap.data;
        if (data == null) return const LoadingView();
        if (data is String) {
          if (!item.isPdf) {
            return InteractiveViewer(child: Center(child: Image.network(data)));
          }
          return EmptyView(
            icon: Icons.picture_as_pdf_outlined,
            title: item.title,
            message: '',
            action: FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text(AppStrings.openFile),
              onPressed: () =>
                  launchUrl(Uri.parse(data), webOnlyWindowName: '_blank'),
            ),
          );
        }
        final bytes = data as Uint8List;
        if (!item.isPdf) {
          return InteractiveViewer(child: Center(child: Image.memory(bytes)));
        }
        _pdf ??= PdfControllerPinch(document: PdfDocument.openData(bytes));
        return PdfViewPinch(controller: _pdf!);
      },
    );
  }
}
