import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../data/models/admin_stats.dart';
import '../../../data/models/note.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/purchases_repository.dart';
import '../../purchases/presentation/purchases_controllers.dart';

part 'admin_ops_controllers.g.dart';

// ── Dashboard ──────────────────────────────────────────────

@riverpod
Future<GlobalStats> adminGlobalStats(Ref ref) =>
    ref.watch(adminRepositoryProvider).globalStats();

/// The last [days] days ending today, oldest first; days without sales
/// are filled with zeros so the chart has no gaps.
List<DailyStat> fillDays(List<DailyStat> stored, DateTime today, int days) {
  final byDate = {for (final d in stored) d.date: d};
  final fmt = DateFormat('yyyy-MM-dd');
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = fmt.format(
          DateTime(today.year, today.month, today.day - i),
        );
        return byDate[day] ?? DailyStat(date: day);
      }(),
  ];
}

@riverpod
Future<List<DailyStat>> adminDailyStats(Ref ref) async => fillDays(
  await ref.watch(adminRepositoryProvider).dailyStats(),
  DateTime.now(),
  30,
);

@riverpod
Future<List<Note>> adminTopNotes(Ref ref) =>
    ref.watch(adminRepositoryProvider).topNotes();

@riverpod
Future<List<PurchaseOrder>> adminRecentPurchases(Ref ref) =>
    ref.watch(adminRepositoryProvider).recentPurchases();

/// Refresh every dashboard number (after "Recalculate stats").
void refreshDashboard(WidgetRef ref) {
  ref
    ..invalidate(adminGlobalStatsProvider)
    ..invalidate(adminDailyStatsProvider)
    ..invalidate(adminTopNotesProvider)
    ..invalidate(adminRecentPurchasesProvider);
}

// ── Paginated lists ────────────────────────────────────────

Future<void> _loadMore<T>(
  Ref ref,
  PagedState<T>? current,
  Future<Paged<T>> Function(Object? cursor) fetch,
  void Function(AsyncValue<PagedState<T>>) write,
) async {
  if (current == null || !current.hasMore || current.loadingMore) return;
  write(
    AsyncData(
      PagedState(
        current.items,
        cursor: current.cursor,
        hasMore: true,
        loadingMore: true,
      ),
    ),
  );
  try {
    final page = await fetch(current.cursor);
    if (!ref.mounted) return;
    write(
      AsyncData(
        PagedState(
          [...current.items, ...page.items],
          cursor: page.cursor,
          hasMore: page.hasMore,
        ),
      ),
    );
  } on Object catch (e, st) {
    ref.read(errorReporterProvider).recordError(e, st);
    if (ref.mounted) write(AsyncData(current));
  }
}

PagedState<T> _paged<T>(Paged<T> p) =>
    PagedState(p.items, cursor: p.cursor, hasMore: p.hasMore);

@riverpod
class AdminUsers extends _$AdminUsers {
  @override
  Future<PagedState<AdminUser>> build(String search) async =>
      _paged(await ref.watch(adminRepositoryProvider).users(search: search));

  Future<void> loadMore() => _loadMore(
    ref,
    state.value,
    (c) => ref.read(adminRepositoryProvider).users(search: search, cursor: c),
    (s) => state = s,
  );
}

@riverpod
class AdminOrders extends _$AdminOrders {
  @override
  Future<PagedState<PurchaseOrder>> build(OrderFilter filter) async =>
      _paged(await ref.watch(adminRepositoryProvider).orders(filter));

  Future<void> loadMore() => _loadMore(
    ref,
    state.value,
    (c) => ref.read(adminRepositoryProvider).orders(filter, cursor: c),
    (s) => state = s,
  );
}

// ── Details ────────────────────────────────────────────────

@riverpod
Future<AdminUser?> adminUser(Ref ref, String uid) =>
    ref.watch(adminRepositoryProvider).user(uid);

/// A student's newest 20 purchases / orders (admin rules allow the read).
@riverpod
Future<List<Purchase>> adminUserPurchases(Ref ref, String uid) async =>
    (await ref.watch(purchasesRepositoryProvider).purchases(uid)).items;

@riverpod
Future<List<PurchaseOrder>> adminUserOrders(Ref ref, String uid) async =>
    (await ref.watch(purchasesRepositoryProvider).orders(uid)).items;

@riverpod
Future<PurchaseOrder?> adminOrder(Ref ref, String id) =>
    ref.watch(adminRepositoryProvider).order(id);
