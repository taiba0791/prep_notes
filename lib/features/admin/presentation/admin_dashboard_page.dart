import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/admin_stats.dart';
import '../../../data/repositories/admin_repository.dart';
import 'admin_ops_controllers.dart';
import 'widgets/admin_widgets.dart';

/// Admin dashboard: live totals, 30-day revenue, top notes, recent sales.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _recalculating = false;

  Future<void> _recalculate() async {
    setState(() => _recalculating = true);
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepositoryProvider).recomputeStats(),
      success: AppStrings.statsRecalculated,
    );
    if (!mounted) return;
    setState(() => _recalculating = false);
    if (ok) refreshDashboard(ref);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final links = [
      (
        AppStrings.adminNotes,
        Icons.description_outlined,
        RoutePaths.adminNotes,
      ),
      (AppStrings.newNote, Icons.add_circle_outline, RoutePaths.adminNoteNew),
      (AppStrings.adminUsers, Icons.people_outline, RoutePaths.adminUsers),
      (
        AppStrings.adminOrders,
        Icons.receipt_long_outlined,
        RoutePaths.adminOrders,
      ),
    ];
    final wide = context.isDesktop;

    return RefreshIndicator(
      onRefresh: () async => refreshDashboard(ref),
      child: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.adminDashboard, style: text.headlineMedium),
                  Text(
                    AppStrings.adminDashboardSubtitle,
                    style: text.bodyMedium,
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _recalculating ? null : _recalculate,
                icon: _recalculating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text(AppStrings.recalculateStats),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _StatCards(),
          const SizedBox(height: 20),
          const _RevenueChart(),
          const SizedBox(height: 20),
          if (wide)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _TopNotes()),
                SizedBox(width: 20),
                Expanded(child: _RecentPurchases()),
              ],
            )
          else ...const [_TopNotes(), SizedBox(height: 20), _RecentPurchases()],
          const SizedBox(height: 20),
          const _Section(
            title: AppStrings.recentFeedback,
            child: Text(AppStrings.feedbackComingSoon),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (label, icon, path) in links)
                OutlinedButton.icon(
                  onPressed: () => context.go(path),
                  icon: Icon(icon),
                  label: Text(label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Loading / error / data for a small dashboard block.
Widget _async<T>(
  AsyncValue<T> value,
  VoidCallback retry,
  Widget Function(T) data,
) => value.when(
  loading: () => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  ),
  error: (_, _) => Center(
    child: TextButton.icon(
      onPressed: retry,
      icon: const Icon(Icons.refresh),
      label: const Text(AppStrings.retry),
    ),
  ),
  data: data,
);

class _StatCards extends ConsumerWidget {
  const _StatCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(adminGlobalStatsProvider);
    final s = stats.value ?? const GlobalStats();
    final cards = [
      (
        AppStrings.adminStatStudents,
        '${s.totalStudents}',
        Icons.people_outline,
      ),
      (
        AppStrings.adminStatNotes,
        '${s.totalNotes}',
        Icons.description_outlined,
      ),
      (
        AppStrings.adminStatPurchases,
        '${s.totalPurchases}',
        Icons.shopping_bag_outlined,
      ),
      (
        AppStrings.adminStatRevenue,
        Money.format(s.totalRevenue),
        Icons.currency_rupee,
      ),
    ];
    if (stats.hasError) {
      return ErrorView(onRetry: () => ref.invalidate(adminGlobalStatsProvider));
    }
    return GridView.count(
      crossAxisCount: context.responsive(mobile: 2, tablet: 2, desktop: 4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: context.isMobile ? 1.5 : 2.2,
      children: [
        for (final (label, value, icon) in cards)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: scheme.secondary),
                      const SizedBox(width: 6),
                      Flexible(child: Text(label, style: text.bodySmall)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      stats.isLoading ? '—' : value,
                      style: text.headlineMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RevenueChart extends ConsumerWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dayLabel = DateFormat('d MMM');

    return _Section(
      title: AppStrings.revenueLast30,
      child: _async(
        ref.watch(adminDailyStatsProvider),
        () => ref.invalidate(adminDailyStatsProvider),
        (days) {
          final total = days.fold(0, (sum, d) => sum + d.revenue);
          final maxY = days.fold(0, (m, d) => d.revenue > m ? d.revenue : m);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Money.format(total), style: text.headlineSmall),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxY <= 0 ? 100 : maxY / 100 * 1.15,
                    gridData: const FlGridData(drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, meta) =>
                              Text('₹${v.toInt()}', style: text.labelSmall),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            // A label every 7 days (and the last day).
                            if (i < 0 ||
                                i >= days.length ||
                                (i % 7 != 0 && i != days.length - 1)) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              dayLabel.format(DateTime.parse(days[i].date)),
                              style: text.labelSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                          '${dayLabel.format(DateTime.parse(days[group.x].date))}\n'
                          '${Money.format(days[group.x].revenue)}',
                          text.labelMedium!.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              // Negative only on a day with refunds > sales.
                              toY: days[i].revenue / 100,
                              color: scheme.primary,
                              width: 6,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopNotes extends ConsumerWidget {
  const _TopNotes();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
    title: AppStrings.topNotes,
    child: _async(
      ref.watch(adminTopNotesProvider),
      () => ref.invalidate(adminTopNotesProvider),
      (notes) => notes.isEmpty
          ? const Text(AppStrings.noSalesYet)
          : Column(
              children: [
                for (final (i, n) in notes.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(AppStrings.soldCount(n.purchaseCount)),
                    onTap: () => context.go(RoutePaths.adminNoteEdit(n.id)),
                  ),
              ],
            ),
    ),
  );
}

class _RecentPurchases extends ConsumerWidget {
  const _RecentPurchases();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('d MMM, h:mm a');
    return _Section(
      title: AppStrings.recentPurchases,
      child: _async(
        ref.watch(adminRecentPurchasesProvider),
        () => ref.invalidate(adminRecentPurchasesProvider),
        (orders) => orders.isEmpty
            ? const Text(AppStrings.noSalesYet)
            : Column(
                children: [
                  for (final o in orders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        o.noteTitles.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        o.paidAt == null ? o.id : date.format(o.paidAt!),
                      ),
                      trailing: Text(Money.format(o.amount)),
                      onTap: () => context.go(RoutePaths.adminOrder(o.id)),
                    ),
                ],
              ),
      ),
    );
  }
}
