import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/note_cover.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/purchase.dart';
import 'purchases_controllers.dart';

final _date = DateFormat('d MMM yyyy');

/// `/purchases` — notes the student owns + their order history.
class MyPurchasesScreen extends StatelessWidget {
  const MyPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.pagePurchases),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.purchasesNotesTab),
              Tab(text: AppStrings.purchasesOrdersTab),
            ],
          ),
        ),
        body: const TabBarView(children: [_NotesTab(), _OrdersTab()]),
      ),
    );
  }
}

/// Centred, readable width on big screens.
class _Column extends StatelessWidget {
  const _Column({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(context.pagePadding),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

Widget _loadMore(bool hasMore, bool loading, VoidCallback onTap) => !hasMore
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : OutlinedButton(
                  onPressed: onTap,
                  child: const Text(AppStrings.loadMore),
                ),
        ),
      );

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab();

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(myPurchasesProvider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) =>
              ErrorView(onRetry: () => ref.invalidate(myPurchasesProvider)),
          data: (page) {
            if (page.items.isEmpty) {
              return EmptyView(
                icon: Icons.library_books_outlined,
                title: AppStrings.noPurchasesTitle,
                message: AppStrings.noPurchasesMessage,
                action: FilledButton(
                  onPressed: () => context.go(RoutePaths.notes),
                  child: const Text(AppStrings.browseAllNotes),
                ),
              );
            }
            final q = _query.trim().toLowerCase();
            final shown = [
              for (final p in page.items)
                if (q.isEmpty ||
                    '${p.title} ${p.subjectName} ${p.universityName}'
                        .toLowerCase()
                        .contains(q))
                  p,
            ];
            return _Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: AppStrings.searchPurchases,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      AppStrings.noMatches,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final p in shown) _PurchaseTile(purchase: p),
                _loadMore(
                  page.hasMore,
                  page.loadingMore,
                  () => ref.read(myPurchasesProvider.notifier).loadMore(),
                ),
              ],
            );
          },
        );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = purchase;
    final sub = [
      if (p.subjectName.isNotEmpty) p.subjectName,
      if (p.universityName.isNotEmpty) p.universityName,
      if (p.purchasedAt != null)
        AppStrings.purchasedOn(_date.format(p.purchasedAt!)),
    ].join(' · ');
    final read = FilledButton(
      onPressed: () => context.push(RoutePaths.noteViewer(p.noteId)),
      child: const Text(AppStrings.readNow),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: () => context.go(RoutePaths.note(p.noteId)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              NoteCover(
                title: p.title,
                thumbnailUrl: p.thumbnailUrl,
                width: 64,
                height: 64,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: text.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (context.isMobile) ...[const SizedBox(height: 8), read],
                  ],
                ),
              ),
              if (!context.isMobile) ...[const SizedBox(width: 12), read],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(myOrdersProvider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) =>
              ErrorView(onRetry: () => ref.invalidate(myOrdersProvider)),
          data: (page) => page.items.isEmpty
              ? const EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: AppStrings.noOrdersTitle,
                  message: AppStrings.noOrdersMessage,
                )
              : _Column(
                  children: [
                    for (final o in page.items) _OrderTile(order: o),
                    _loadMore(
                      page.hasMore,
                      page.loadingMore,
                      () => ref.read(myOrdersProvider.notifier).loadMore(),
                    ),
                  ],
                ),
        );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (order.status) {
      OrderStatus.paid => (
        AppStrings.orderStatusPaid,
        context.appColors.success,
      ),
      OrderStatus.failed => (AppStrings.orderStatusFailed, scheme.error),
      OrderStatus.refunded => (
        AppStrings.orderStatusRefunded,
        scheme.secondary,
      ),
      _ => (AppStrings.orderStatusCreated, scheme.outline),
    };
    final when = order.paidAt ?? order.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(
          order.noteTitles.isEmpty ? order.id : order.noteTitles.join(', '),
          style: text.titleMedium,
        ),
        subtitle: SelectableText(
          [
            AppStrings.orderIdLabel(order.id),
            if (when != null) _date.format(when),
            if (order.failureReason != null) order.failureReason!,
          ].join(' · '),
          style: text.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Money.format(order.amount), style: text.titleMedium),
            Text(
              label,
              style: text.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
