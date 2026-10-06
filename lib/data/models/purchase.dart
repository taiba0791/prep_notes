import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters/timestamp_converter.dart';
import 'note.dart';

part 'purchase.freezed.dart';
part 'purchase.g.dart';

/// `users/{uid}/entitlements/{noteId}` — a note the student owns.
/// Written ONLY by Cloud Functions after payment; holds a small copy of the
/// note so "My Purchases" needs no extra reads.
@freezed
abstract class Purchase with _$Purchase {
  const factory Purchase({
    required String noteId,
    @Default('') String orderId,
    @TimestampConverter() DateTime? purchasedAt,
    @Default(0) int pricePaid, // paise
    @Default('') String title,
    @Default('') String universityName,
    @Default(0) int semesterNumber,
    @Default('') String subjectName,
    String? thumbnailUrl,
    @Default(0) int pageCount,
  }) = _Purchase;

  const Purchase._();

  factory Purchase.fromJson(Map<String, dynamic> json) =>
      _$PurchaseFromJson(json);

  /// Enough of a [Note] to draw a note card.
  Note toNote() => Note(
    id: noteId,
    title: title,
    universityId: '',
    semesterId: '',
    subjectId: '',
    moduleId: '',
    universityName: universityName,
    semesterNumber: semesterNumber,
    subjectName: subjectName,
    price: pricePaid,
    thumbnailUrl: thumbnailUrl,
    pageCount: pageCount,
    isPublished: true,
  );
}

/// `orders/{orderId}` — one checkout attempt. Written ONLY by Cloud Functions.
@freezed
abstract class PurchaseOrder with _$PurchaseOrder {
  const factory PurchaseOrder({
    required String id,
    required String userId,
    @Default(<String>[]) List<String> noteIds,
    @Default(<String>[]) List<String> noteTitles,
    @Default(0) int amount, // paise
    @Default('INR') String currency,
    @Default('created') String status, // see OrderStatus
    String? razorpayPaymentId,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? paidAt,
    String? failureReason,
  }) = _PurchaseOrder;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) =>
      _$PurchaseOrderFromJson(json);
}

/// What `createOrder` returns: everything Razorpay Checkout needs.
@freezed
abstract class CheckoutOrder with _$CheckoutOrder {
  const factory CheckoutOrder({
    required String orderId,
    required int amount, // paise
    required String currency,
    required String keyId,
    @Default('') String noteTitle,
    @Default('') String email,
  }) = _CheckoutOrder;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) =>
      _$CheckoutOrderFromJson(json);
}
