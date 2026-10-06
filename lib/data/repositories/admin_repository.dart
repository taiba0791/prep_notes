import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../models/admin_stats.dart';
import '../models/note.dart';
import '../models/purchase.dart';
import '../models/user_profile.dart';
import 'purchases_repository.dart';

part 'admin_repository.g.dart';

/// Filters for the admin orders list.
class OrderFilter {
  const OrderFilter({this.status, this.from, this.to});

  /// One of [OrderStatus], or null for all.
  final String? status;

  /// Inclusive day range on `createdAt` (local dates).
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is OrderFilter &&
      other.status == status &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(status, from, to);
}

/// A failed admin action, with the server's explanation.
class AdminActionException implements Exception {
  const AdminActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Names of the admin Cloud Functions.
abstract final class AdminFunctions {
  static const recomputeStats = 'recomputeStats';
  static const setUserDisabled = 'setUserDisabled';
  static const setAdminClaim = 'setAdminClaim';
  static const markOrderRefunded = 'markOrderRefunded';
  static const setRoomPlanPrice = 'setRoomPlanPrice';
}

/// Everything the admin dashboard, Users and Orders pages read and do.
/// Firestore rules only let admins run these reads; the actions are Cloud
/// Functions that check the admin claim again on the server.
abstract interface class AdminRepository {
  static const pageSize = 20;
  static const exportLimit = 5000;

  Future<GlobalStats> globalStats();

  /// Newest [days] days that have a document (oldest first).
  Future<List<DailyStat>> dailyStats({int days = 30});
  Future<List<Note>> topNotes({int limit = 5});
  Future<List<PurchaseOrder>> recentPurchases({int limit = 10});

  /// Newest first; [search] with "@" = email prefix, otherwise name prefix.
  Future<Paged<AdminUser>> users({String search = '', Object? cursor});
  Future<AdminUser?> user(String uid);

  Future<Paged<PurchaseOrder>> orders(OrderFilter filter, {Object? cursor});
  Future<List<PurchaseOrder>> ordersForExport(OrderFilter filter);
  Future<PurchaseOrder?> order(String id);

  Future<void> recomputeStats();
  Future<void> setUserDisabled(String uid, {required bool disabled});
  Future<void> setAdmin(String email, {required bool admin});

  /// RECORDS a refund made in the Razorpay Dashboard (moves no money).
  Future<void> markOrderRefunded(String orderId, {String reason = ''});

  /// New price (paise) for a Resource Room plan (m1 | m3 | m6).
  Future<void> setRoomPlanPrice(String planKey, int price);
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository(
    this._db, {
    required FirebaseFunctions Function() functions,
  }) : _functionsOf = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions Function() _functionsOf;

  static AdminUser _user(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    return AdminUser(
      profile: UserProfile.fromJson(data).copyWith(uid: d.id),
      disabled: data[UserFields.disabled] == true,
    );
  }

  static PurchaseOrder _order(DocumentSnapshot<Map<String, dynamic>> d) =>
      PurchaseOrder.fromJson({...d.data()!, 'id': d.id});

  static Paged<T> _page<T>(
    QuerySnapshot<Map<String, dynamic>> snap,
    T Function(DocumentSnapshot<Map<String, dynamic>>) map,
    Object? cursor,
  ) => (
    items: [for (final d in snap.docs) map(d)],
    cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
    hasMore: snap.docs.length == AdminRepository.pageSize,
  );

  @override
  Future<GlobalStats> globalStats() async {
    final d = await _db.doc(FirestorePaths.statsGlobal).get();
    return d.exists ? GlobalStats.fromJson(d.data()!) : const GlobalStats();
  }

  @override
  Future<List<DailyStat>> dailyStats({int days = 30}) async {
    final snap = await _db
        .collection(FirestoreCollections.statsDaily)
        .orderBy(DailyStatsFields.date, descending: true)
        .limit(days)
        .get();
    return [
      for (final d in snap.docs.reversed)
        DailyStat.fromJson({...d.data(), DailyStatsFields.date: d.id}),
    ];
  }

  @override
  Future<List<Note>> topNotes({int limit = 5}) async {
    final snap = await _db
        .collection(FirestoreCollections.notes)
        .where(NoteFields.purchaseCount, isGreaterThan: 0)
        .orderBy(NoteFields.purchaseCount, descending: true)
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs) Note.fromJson(d.data()).copyWith(id: d.id),
    ];
  }

  @override
  Future<List<PurchaseOrder>> recentPurchases({int limit = 10}) async {
    final snap = await _db
        .collection(FirestoreCollections.orders)
        .where(OrderFields.status, isEqualTo: OrderStatus.paid)
        .orderBy(OrderFields.paidAt, descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) _order(d)];
  }

  @override
  Future<Paged<AdminUser>> users({String search = '', Object? cursor}) async {
    final s = search.trim().toLowerCase();
    var q = _db
        .collection(FirestoreCollections.users)
        .limit(AdminRepository.pageSize);
    if (s.isEmpty) {
      q = q.orderBy(UserFields.createdAt, descending: true);
    } else {
      // Prefix search: everything from "s" up to "s" + the last character.
      final field = s.contains('@') ? UserFields.email : UserFields.nameLower;
      q = q.orderBy(field).startAt([s]).endAt(['$s']);
    }
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    return _page(await q.get(), _user, cursor);
  }

  @override
  Future<AdminUser?> user(String uid) async {
    final d = await _db.doc(FirestorePaths.user(uid)).get();
    return d.exists ? _user(d) : null;
  }

  Query<Map<String, dynamic>> _ordersQuery(OrderFilter f) {
    Query<Map<String, dynamic>> q = _db.collection(FirestoreCollections.orders);
    if (f.status != null) q = q.where(OrderFields.status, isEqualTo: f.status);
    if (f.from != null) {
      final from = DateTime(f.from!.year, f.from!.month, f.from!.day);
      q = q.where(
        OrderFields.createdAt,
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (f.to != null) {
      final end = DateTime(f.to!.year, f.to!.month, f.to!.day + 1);
      q = q.where(OrderFields.createdAt, isLessThan: Timestamp.fromDate(end));
    }
    return q.orderBy(OrderFields.createdAt, descending: true);
  }

  @override
  Future<Paged<PurchaseOrder>> orders(
    OrderFilter filter, {
    Object? cursor,
  }) async {
    var q = _ordersQuery(filter).limit(AdminRepository.pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    return _page(await q.get(), _order, cursor);
  }

  @override
  Future<List<PurchaseOrder>> ordersForExport(OrderFilter filter) async {
    final snap = await _ordersQuery(filter)
        .limit(AdminRepository.exportLimit)
        .get();
    return [for (final d in snap.docs) _order(d)];
  }

  @override
  Future<PurchaseOrder?> order(String id) async {
    final d = await _db.doc(FirestorePaths.order(id)).get();
    return d.exists ? _order(d) : null;
  }

  Future<void> _call(String name, Map<String, Object?> data) async {
    try {
      await _functionsOf().httpsCallable(name).call<Object?>(data);
    } on FirebaseFunctionsException catch (e) {
      throw AdminActionException(e.message ?? e.code);
    }
  }

  @override
  Future<void> recomputeStats() => _call(AdminFunctions.recomputeStats, {});

  @override
  Future<void> setUserDisabled(String uid, {required bool disabled}) =>
      _call(AdminFunctions.setUserDisabled, {'uid': uid, 'disabled': disabled});

  @override
  Future<void> setAdmin(String email, {required bool admin}) =>
      _call(AdminFunctions.setAdminClaim, {'email': email, 'admin': admin});

  @override
  Future<void> setRoomPlanPrice(String planKey, int price) => _call(
    AdminFunctions.setRoomPlanPrice,
    {'planKey': planKey, 'price': price},
  );

  @override
  Future<void> markOrderRefunded(String orderId, {String reason = ''}) => _call(
    AdminFunctions.markOrderRefunded,
    {'orderId': orderId, 'reason': reason},
  );
}

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) => FirebaseAdminRepository(
  ref.watch(firestoreProvider),
  functions: () => ref.read(functionsProvider),
);
