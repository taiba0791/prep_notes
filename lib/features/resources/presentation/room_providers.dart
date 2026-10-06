import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../data/models/access.dart';
import '../../../data/repositories/room_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../purchases/presentation/purchases_controllers.dart';

part 'room_providers.g.dart';

/// Search + type filter for the Room list.
class RoomFilter {
  const RoomFilter({this.search = '', this.type});

  final String search;
  final String? type; // RoomItemType or null = all

  @override
  bool operator ==(Object other) =>
      other is RoomFilter && other.search == search && other.type == type;

  @override
  int get hashCode => Object.hash(search, type);
}

/// The student's Room items for [filter], newest first, with "Load more".
@riverpod
class RoomItems extends _$RoomItems {
  @override
  Future<PagedState<RoomItem>> build(RoomFilter filter) async {
    final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
    if (uid == null) return const PagedState([]);
    final page = await ref
        .watch(roomRepositoryProvider)
        .items(uid, search: filter.search, type: filter.type);
    return PagedState(page.items, cursor: page.cursor, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final uid = ref.read(authSessionProvider).value?.uid;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        uid == null) {
      return;
    }
    state = AsyncData(
      PagedState(
        current.items,
        cursor: current.cursor,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(roomRepositoryProvider)
          .items(
            uid,
            search: filter.search,
            type: filter.type,
            cursor: current.cursor,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        PagedState(
          [...current.items, ...page.items],
          cursor: page.cursor,
          hasMore: page.hasMore,
        ),
      );
    } on Object catch (e, st) {
      ref.read(errorReporterProvider).recordError(e, st);
      if (ref.mounted) state = AsyncData(current);
    }
  }
}

/// One item (the viewer screen).
@riverpod
Future<RoomItem?> roomItem(Ref ref, String itemId) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return null;
  return ref.watch(roomRepositoryProvider).item(uid, itemId);
}

/// After adding / renaming / deleting: refresh the list and the usage bar.
void refreshRoom(WidgetRef ref) {
  ref
    ..invalidate(roomItemsProvider)
    ..invalidate(roomAccessProvider);
}
