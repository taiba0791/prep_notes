import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import 'converters/timestamp_converter.dart';

part 'access.freezed.dart';
part 'access.g.dart';

/// `users/{uid}/bundles/{semesterId}` — a semester bundle (written by
/// Cloud Functions). Unlocks all the semester's notes + the Resource Room.
@freezed
abstract class SemesterBundle with _$SemesterBundle {
  const factory SemesterBundle({
    required String semesterId,
    @Default('') String universityId,
    @Default('') String universityName,
    @Default(0) int semesterNumber,
    @Default('') String semesterName,
    @Default('') String orderId,
    @Default(0) int pricePaid, // paise
    @TimestampConverter() DateTime? purchasedAt,
    @TimestampConverter() DateTime? expiresAt,
  }) = _SemesterBundle;

  const SemesterBundle._();

  factory SemesterBundle.fromJson(Map<String, dynamic> json) =>
      _$SemesterBundleFromJson(json);

  bool isActiveAt(DateTime now) => expiresAt != null && expiresAt!.isAfter(now);
}

/// `subscriptions/{id}` — a Resource Room subscription (auto-renew).
@freezed
abstract class RoomSubscription with _$RoomSubscription {
  const factory RoomSubscription({
    required String id,
    required String userId,
    @Default('m1') String planKey,
    @Default(0) int amount, // paise per period
    @Default('created') String status,
    @TimestampConverter() DateTime? currentEnd,
    @Default(false) bool cancelAtPeriodEnd,
    @TimestampConverter() DateTime? createdAt,
  }) = _RoomSubscription;

  const RoomSubscription._();

  factory RoomSubscription.fromJson(Map<String, dynamic> json) =>
      _$RoomSubscriptionFromJson(json);

  /// Still charging (or being set up / retrying a failed charge).
  bool get renews =>
      !cancelAtPeriodEnd &&
      const {'authenticated', 'active', 'pending'}.contains(status);

  bool isPaidAt(DateTime now) => currentEnd != null && currentEnd!.isAfter(now);
}

/// One Room plan (1, 3 or 6 months).
class RoomPlan {
  const RoomPlan({
    required this.key,
    required this.months,
    required this.price,
  });

  final String key; // m1 | m3 | m6
  final int months;
  final int price; // paise

  /// Defaults until the admin changes prices (config/roomPlans).
  static const defaults = [
    RoomPlan(key: 'm1', months: 1, price: 14900),
    RoomPlan(key: 'm3', months: 3, price: 39900),
    RoomPlan(key: 'm6', months: 6, price: 74900),
  ];

  /// Reads config/roomPlans (missing plans fall back to the defaults).
  static List<RoomPlan> fromConfig(Map<String, dynamic>? data) => [
    for (final d in defaults)
      switch (data?[d.key]) {
        {'price': final int price} => RoomPlan(
          key: d.key,
          months: d.months,
          price: price,
        ),
        _ => d,
      },
  ];
}

/// Is the student's Resource Room open, and how full is it?
class RoomAccess {
  const RoomAccess({this.until, this.bytesUsed = 0});

  /// users/{uid}.roomAccessUntil — set by Cloud Functions.
  final DateTime? until;
  final int bytesUsed;

  static const closed = RoomAccess();

  bool isOpenAt(DateTime now) => until != null && until!.isAfter(now);

  /// Days left (0 when closed).
  int daysLeftAt(DateTime now) =>
      isOpenAt(now) ? until!.difference(now).inHours ~/ 24 : 0;

  int get bytesLeft => (AccessRules.roomQuotaBytes - bytesUsed).clamp(
    0,
    AccessRules.roomQuotaBytes,
  );
}

/// Can the student open a note, and why.
enum NoteAccessKind { none, owner, bundle }

class NoteAccess {
  const NoteAccess(this.kind, {this.until});

  static const none = NoteAccess(NoteAccessKind.none);

  final NoteAccessKind kind;
  final DateTime? until;

  bool get canRead => kind != NoteAccessKind.none;
}

/// `users/{uid}/roomItems/{itemId}`
@freezed
abstract class RoomItem with _$RoomItem {
  const factory RoomItem({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String id,
    required String type, // see RoomItemType
    required String title,
    String? url,
    String? storagePath,
    String? fileName,
    String? contentType,
    @Default(0) int sizeBytes,
    @TimestampConverter() DateTime? createdAt,
    @Default(<String>[]) List<String> searchKeywords,
  }) = _RoomItem;

  const RoomItem._();

  factory RoomItem.fromJson(Map<String, dynamic> json) =>
      _$RoomItemFromJson(json);

  bool get isFile => type == RoomItemType.file;
  bool get isPdf => contentType == 'application/pdf';
}
