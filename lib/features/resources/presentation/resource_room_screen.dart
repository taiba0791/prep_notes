import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/access.dart';
import '../../../data/repositories/room_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../purchases/data/payment_service.dart';
import '../../purchases/presentation/checkout_screen.dart';
import '../../purchases/presentation/purchases_controllers.dart';
import '../domain/room_links.dart';
import 'room_providers.dart';

final _day = DateFormat('d MMM yyyy');

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String roomErrorMessage(Object e) => switch (e) {
  RoomException(error: RoomError.notOpen) => AppStrings.roomNotOpen,
  RoomException(error: RoomError.badLink) => AppStrings.roomBadLink,
  RoomException(error: RoomError.tooBig) => AppStrings.roomTooBig,
  RoomException(error: RoomError.quotaFull) => AppStrings.roomQuotaFull,
  RoomException(error: RoomError.badType) => AppStrings.roomBadType,
  _ => AppStrings.roomFailed,
};

IconData roomItemIcon(String type) => switch (type) {
  RoomItemType.youtube => Icons.smart_display_outlined,
  RoomItemType.drive => Icons.add_to_drive_outlined,
  _ => Icons.description_outlined,
};

/// `/resources` — the Resource Room. Premium: open with an active semester
/// bundle or a Room subscription; otherwise shows how to get it.
class ResourceRoomScreen extends ConsumerWidget {
  const ResourceRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(roomAccessProvider);
    return Scaffold(
      appBar: context.isMobile
          ? AppBar(title: const Text(AppStrings.roomTitle))
          : null,
      body: access.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(roomAccessProvider)),
        data: (a) =>
            a.isOpenAt(DateTime.now()) ? _Locker(access: a) : const _Offer(),
      ),
    );
  }
}

// ── Not open: what the Room is and how to get it ───────────

class _Offer extends ConsumerWidget {
  const _Offer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final plans = ref.watch(roomPlansProvider).value ?? RoomPlan.defaults;
    final buyInApp = ref.watch(buyInAppProvider);

    return ListView(
      children: [
        PageContainer(
          vertical: context.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: InfoPill(AppStrings.roomPremium),
              ),
              const SizedBox(height: 12),
              const AccentHeading(start: 'Resource ', accent: 'Room'),
              const SizedBox(height: 10),
              Text(AppStrings.roomTagline, style: text.bodyLarge),
              const SizedBox(height: 16),
              for (final f in const [
                AppStrings.roomFeatureLinks,
                AppStrings.roomFeatureFiles,
                AppStrings.roomFeatureInApp,
                AppStrings.roomFeatureSearch,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: context.appColors.success),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: text.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                color: context.appColors.cream,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(Icons.library_books, color: scheme.primary),
                  title: Text(
                    AppStrings.roomWithBundle,
                    style: text.titleMedium,
                  ),
                  subtitle: const Text(AppStrings.bundleTitle),
                  trailing: FilledButton(
                    onPressed: () => context.go(RoutePaths.notes),
                    child: const Text(AppStrings.seeBundles),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(AppStrings.roomOrSubscribe, style: text.titleLarge),
              const SizedBox(height: 12),
              ResponsiveGrid(
                spacing: 16,
                desktopColumns: 3,
                children: [
                  for (final p in plans)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.planName(p.months),
                              style: text.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Money.format(p.price),
                              style: text.headlineMedium,
                            ),
                            Text(
                              AppStrings.perMonths(p.months),
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            if (buyInApp)
                              FilledButton(
                                onPressed: () => context.push(
                                  RoutePaths.checkoutRoom(p.key),
                                ),
                                child: const Text(AppStrings.subscribe),
                              )
                            else
                              const BuyOnWebsiteButton(
                                noteId: '',
                                path: RoutePaths.resources,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(AppStrings.autoRenewNote, style: text.bodySmall),
            ],
          ),
        ),
        const SiteFooter(),
      ],
    );
  }
}

// ── Open: the student's locker ─────────────────────────────

class _Locker extends ConsumerStatefulWidget {
  const _Locker({required this.access});

  final RoomAccess access;

  @override
  ConsumerState<_Locker> createState() => _LockerState();
}

class _LockerState extends ConsumerState<_Locker> {
  String _search = '';
  String? _type;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  RoomFilter get _filter => RoomFilter(search: _search, type: _type);

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text(AppStrings.roomAddLink),
              subtitle: const Text(AppStrings.roomFeatureLinks),
              onTap: () => Navigator.pop(context, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text(AppStrings.roomUpload),
              subtitle: const Text(AppStrings.roomFeatureFiles),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'link') {
      await showDialog<void>(
        context: context,
        builder: (_) => const AddLinkDialog(),
      );
    } else {
      await _upload();
    }
  }

  Future<void> _upload() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ref.read(filePickerServiceProvider).pickPdfOrImage();
    if (picked == null || !mounted) return;
    if (picked.bytes.length > AccessRules.roomMaxFileBytes) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.roomTooBig)),
      );
      return;
    }
    if (picked.bytes.length > widget.access.bytesLeft) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.roomQuotaFull)),
      );
      return;
    }
    final uid = ref.read(authSessionProvider).value?.uid;
    if (uid == null) return;
    final title = picked.name.contains('.')
        ? picked.name.substring(0, picked.name.lastIndexOf('.'))
        : picked.name;
    final progress = ValueNotifier<double>(0);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.roomUploading),
          content: ValueListenableBuilder(
            valueListenable: progress,
            builder: (_, v, _) =>
                LinearProgressIndicator(value: v == 0 ? null : v),
          ),
        ),
      ),
    );
    String message = AppStrings.roomSaved;
    try {
      await ref
          .read(roomRepositoryProvider)
          .addFile(
            uid,
            bytes: picked.bytes,
            fileName: picked.name,
            contentType: picked.contentType,
            title: title,
            onProgress: (p) => progress.value = p,
          );
    } on Object catch (e) {
      message = roomErrorMessage(e);
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    messenger.showSnackBar(SnackBar(content: Text(message)));
    refreshRoom(ref);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final a = widget.access;
    final now = DateTime.now();
    final sub = ref.watch(roomSubscriptionProvider).value;
    final days = a.daysLeftAt(now);
    final showWarning =
        days <= AccessRules.roomWarningDays && !(sub?.renews ?? false);
    final items = ref.watch(roomItemsProvider(_filter));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.roomAdd),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          context.pagePadding,
          context.pagePadding,
          96,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!context.isMobile)
                    const AccentHeading(start: 'Resource ', accent: 'Room'),
                  if (showWarning) ...[
                    const SizedBox(height: 12),
                    MaterialBanner(
                      backgroundColor: scheme.errorContainer,
                      content: Text(
                        AppStrings.roomEndsIn(days, _day.format(a.until!)),
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => context.go(RoutePaths.purchases),
                          child: const Text(AppStrings.roomKeepAccess),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: AppStrings.roomSearchHint,
                    ),
                    onChanged: _onSearch,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, type) in const [
                        (AppStrings.roomAll, null),
                        (AppStrings.roomDrive, RoomItemType.drive),
                        (AppStrings.roomYoutube, RoomItemType.youtube),
                        (AppStrings.roomFiles, RoomItemType.file),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: a.bytesUsed / AccessRules.roomQuotaBytes,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.roomUsage(
                      _mb(a.bytesUsed),
                      _mb(AccessRules.roomQuotaBytes),
                    ),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  items.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => ErrorView(
                      onRetry: () => ref.invalidate(roomItemsProvider(_filter)),
                    ),
                    data: (page) => page.items.isEmpty
                        ? const EmptyView(
                            icon: Icons.inventory_2_outlined,
                            title: AppStrings.roomEmptyTitle,
                            message: AppStrings.roomEmptyMessage,
                          )
                        : Column(
                            children: [
                              for (final item in page.items)
                                _ItemTile(item: item),
                              if (page.hasMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: page.loadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () => ref
                                              .read(
                                                roomItemsProvider(_filter)
                                                    .notifier,
                                              )
                                              .loadMore(),
                                          child: const Text(
                                            AppStrings.loadMore,
                                          ),
                                        ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final RoomItem item;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.roomRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: AppStrings.roomTitleLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(AppStrings.roomSave),
          ),
        ],
      ),
    );
    controller.dispose();
    final uid = ref.read(authSessionProvider).value?.uid;
    if (title == null || title.isEmpty || uid == null) return;
    await ref.read(roomRepositoryProvider).rename(uid, item.id, title);
    refreshRoom(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteConfirmTitle(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    final uid = ref.read(authSessionProvider).value?.uid;
    if (ok != true || uid == null) return;
    await ref.read(roomRepositoryProvider).delete(uid, item.id);
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.roomDeleted)),
    );
    refreshRoom(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sub = [
      switch (item.type) {
        RoomItemType.youtube => AppStrings.roomYoutube,
        RoomItemType.drive => AppStrings.roomDrive,
        _ => '${item.fileName ?? ''} · ${_mb(item.sizeBytes)}',
      },
      if (item.createdAt != null) _day.format(item.createdAt!),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: CircleAvatar(
          backgroundColor: context.appColors.cream,
          child: Icon(roomItemIcon(item.type), color: scheme.secondary),
        ),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => context.push(RoutePaths.roomItem(item.id)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) =>
              v == 'rename' ? _rename(context, ref) : _delete(context, ref),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text(AppStrings.roomRename)),
            PopupMenuItem(value: 'delete', child: Text(AppStrings.delete)),
          ],
        ),
      ),
    );
  }
}

/// Paste a Drive / YouTube link and give it a title.
class AddLinkDialog extends ConsumerStatefulWidget {
  const AddLinkDialog({super.key});

  @override
  ConsumerState<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends ConsumerState<AddLinkDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _title = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final link = RoomLink.parse(_url.text)!;
    final uid = ref.read(authSessionProvider).value?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(roomRepositoryProvider)
          .addLink(uid, type: link.type, url: link.url, title: _title.text);
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.roomSaved)),
      );
      if (mounted) Navigator.pop(context);
      refreshRoom(ref);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(roomErrorMessage(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.roomAddLink),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _url,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: AppStrings.roomLinkLabel,
                  helperText: AppStrings.roomLinkHelp,
                  helperMaxLines: 3,
                ),
                validator: (v) => RoomLink.parse(v ?? '') == null
                    ? AppStrings.roomBadLink
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: AppStrings.roomTitleLabel,
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? AppStrings.roomTitleRequired
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text(AppStrings.roomSave),
        ),
      ],
    );
  }
}
