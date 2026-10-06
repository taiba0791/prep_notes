import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/services/file_download.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/admin_repository.dart';
import '../domain/orders_csv.dart';
import 'admin_ops_controllers.dart';
import 'widgets/admin_widgets.dart';

final _day = DateFormat('d MMM yyyy');
final _dayTime = DateFormat('d MMM yyyy, h:mm a');

String orderStatusLabel(String status) => switch (status) {
  OrderStatus.paid => AppStrings.orderStatusPaid,
  OrderStatus.failed => AppStrings.orderStatusFailed,
  OrderStatus.refunded => AppStrings.orderStatusRefunded,
  _ => AppStrings.orderStatusCreated,
};

/// Coloured status label for an order.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      OrderStatus.paid => context.appColors.success,
      OrderStatus.failed => scheme.error,
      OrderStatus.refunded => scheme.secondary,
      _ => scheme.outline,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(orderStatusLabel(status)),
      labelStyle: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color),
    );
  }
}

/// `/admin/orders` — all orders with status / date filters and CSV export.
class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  OrderFilter _filter = const OrderFilter();
  bool _exporting = false;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _filter.from == null
          ? null
          : DateTimeRange(start: _filter.from!, end: _filter.to ?? now),
    );
    if (range == null || !mounted) return;
    setState(
      () => _filter = OrderFilter(
        status: _filter.status,
        from: range.start,
        to: range.end,
      ),
    );
  }

  Future<void> _export() async {
    final downloader = ref.read(fileDownloaderProvider);
    if (!downloader.isSupported) {
      showSnack(context, AppStrings.exportWebOnly);
      return;
    }
    setState(() => _exporting = true);
    try {
      final orders = await ref
          .read(adminRepositoryProvider)
          .ordersForExport(_filter);
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      downloader.saveText(
        'prepnotes-orders-$stamp.csv',
        ordersToCsv(orders),
        mimeType: 'text/csv',
      );
      if (mounted) showSnack(context, AppStrings.exported(orders.length));
    } on Object catch (e) {
      if (mounted) showSnack(context, catalogErrorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = adminOrdersProvider(_filter);
    final f = _filter;
    final dates = f.from == null
        ? AppStrings.anyDate
        : '${_day.format(f.from!)} – ${_day.format(f.to ?? f.from!)}';

    final filters = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: context.isMobile ? double.infinity : 220,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: f.status,
            decoration: const InputDecoration(
              labelText: AppStrings.orderColumnStatus,
            ),
            items: [
              const DropdownMenuItem(child: Text(AppStrings.allStatuses)),
              for (final s in const [
                OrderStatus.paid,
                OrderStatus.failed,
                OrderStatus.created,
                OrderStatus.refunded,
              ])
                DropdownMenuItem(value: s, child: Text(orderStatusLabel(s))),
            ],
            onChanged: (s) => setState(
              () => _filter = OrderFilter(status: s, from: f.from, to: f.to),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickDates,
          icon: const Icon(Icons.date_range),
          label: Text(dates),
        ),
        if (f.status != null || f.from != null)
          TextButton(
            onPressed: () => setState(() => _filter = const OrderFilter()),
            child: const Text(AppStrings.clearFilters),
          ),
      ],
    );

    return AdminPage(
      title: AppStrings.adminOrders,
      actions: [
        OutlinedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: const Icon(Icons.download),
          label: const Text(AppStrings.exportCsv),
        ),
      ],
      filters: filters,
      child: ref
          .watch(provider)
          .when(
            loading: () => const LoadingView(),
            error: (_, _) => ErrorView(onRetry: () => ref.invalidate(provider)),
            data: (page) => page.items.isEmpty
                ? const EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: AppStrings.noOrdersMatch,
                    message: '',
                  )
                : AdminTable<PurchaseOrder>(
                    items: page.items,
                    title: (o) => o.noteTitles.join(', '),
                    subtitle: (o) => [
                      Money.format(o.amount),
                      orderStatusLabel(o.status),
                      if (o.createdAt != null) _day.format(o.createdAt!),
                    ].join(' · '),
                    columns: [
                      AdminColumn(
                        AppStrings.orderColumnDate,
                        (o) => Text(
                          o.createdAt == null ? '—' : _day.format(o.createdAt!),
                        ),
                      ),
                      AdminColumn(
                        AppStrings.orderColumnNotes,
                        (o) => ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            o.noteTitles.join(', '),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      AdminColumn(
                        AppStrings.orderColumnAmount,
                        (o) => Text(Money.format(o.amount)),
                        numeric: true,
                      ),
                      AdminColumn(
                        AppStrings.orderColumnStatus,
                        (o) => OrderStatusChip(status: o.status),
                      ),
                    ],
                    actions: (o) => [
                      IconButton(
                        tooltip: AppStrings.pageAdminOrder,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            context.go(RoutePaths.adminOrder(o.id)),
                      ),
                    ],
                    footer: loadMoreButton(
                      hasMore: page.hasMore,
                      loading: page.loadingMore,
                      onPressed: () => ref.read(provider.notifier).loadMore(),
                    ),
                  ),
          ),
    );
  }
}

/// `/admin/orders/:orderId`
class AdminOrderPage extends ConsumerWidget {
  const AdminOrderPage({required this.orderId, super.key});

  final String orderId;

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RefundDialog(),
    );
    if (reason == null || !context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .markOrderRefunded(orderId, reason: reason),
      success: AppStrings.refundRecorded,
    );
    if (ok) {
      ref
        ..invalidate(adminOrderProvider(orderId))
        ..invalidate(adminOrdersProvider)
        ..invalidate(adminGlobalStatsProvider)
        ..invalidate(adminDailyStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final provider = adminOrderProvider(orderId);
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(onRetry: () => ref.invalidate(provider)),
          data: (o) {
            if (o == null) {
              return const EmptyView(
                icon: Icons.receipt_long_outlined,
                title: AppStrings.orderNotFound,
                message: '',
              );
            }
            String when(DateTime? d) => d == null ? '—' : _dayTime.format(d);
            final rows = <(String, String)>[
              (AppStrings.orderColumnNotes, o.noteTitles.join(', ')),
              (AppStrings.orderColumnAmount, Money.format(o.amount)),
              (AppStrings.orderCreated, when(o.createdAt)),
              if (o.paidAt != null) (AppStrings.orderPaid, when(o.paidAt)),
              (AppStrings.orderRazorpayOrderId, o.id),
              if (o.razorpayPaymentId != null)
                (AppStrings.orderPaymentId, o.razorpayPaymentId!),
              if (o.failureReason != null)
                (AppStrings.orderFailureReason, o.failureReason!),
              if (o.refundedAt != null)
                (AppStrings.orderRefunded, when(o.refundedAt)),
              if (o.refundReason?.isNotEmpty ?? false)
                (AppStrings.orderRefundReason, o.refundReason!),
            ];
            return ListView(
              padding: EdgeInsets.all(context.pagePadding),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(AppStrings.pageAdminOrder, style: text.headlineMedium),
                    OrderStatusChip(status: o.status),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (label, value) in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: text.labelMedium),
                                SelectableText(value, style: text.bodyLarge),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.go(RoutePaths.adminUser(o.userId)),
                      icon: const Icon(Icons.person_outline),
                      label: const Text(AppStrings.orderStudent),
                    ),
                    if (o.status == OrderStatus.paid)
                      FilledButton.icon(
                        onPressed: () => _refund(context, ref),
                        icon: const Icon(Icons.undo),
                        label: const Text(AppStrings.markRefunded),
                      ),
                  ],
                ),
              ],
            );
          },
        );
  }
}

/// Explains that money moves in Razorpay; returns the reason, or null.
class _RefundDialog extends StatefulWidget {
  const _RefundDialog();

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text(AppStrings.refundDialogTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(AppStrings.refundDialogMessage),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: AppStrings.refundReasonLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text(AppStrings.markRefunded),
        ),
      ],
    );
  }
}
