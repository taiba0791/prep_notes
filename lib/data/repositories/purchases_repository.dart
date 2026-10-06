import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';
import '../../features/purchases/domain/purchase_failure.dart';
import '../models/purchase.dart';

part 'purchases_repository.g.dart';

/// One page of a list + where to continue.
typedef Paged<T> = ({List<T> items, Object? cursor, bool hasMore});

/// Names of the payment Cloud Functions (functions/src/payments).
abstract final class PaymentFunctions {
  static const createOrder = 'createOrder';
  static const verifyPayment = 'verifyPayment';
  static const getNoteFileUrl = 'getNoteFileUrl';
}

/// Purchases, orders and paid files. The app can only READ purchases;
/// creating orders, confirming payments and opening PDFs all go through
/// Cloud Functions, which check everything.
abstract interface class PurchasesRepository {
  static const pageSize = 20;

  /// Notes the student owns, newest first.
  Future<Paged<Purchase>> purchases(String uid, {Object? cursor});

  /// The student's orders (paid, failed, pending), newest first.
  Future<Paged<PurchaseOrder>> orders(String uid, {Object? cursor});

  /// Step 1 of checkout. The server sets the price.
  Future<CheckoutOrder> createOrder(String noteId);

  /// Step 3: send Razorpay's proof of payment to the server.
  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });

  /// A link to the full PDF that works for about 10 minutes.
  Future<String> noteFileUrl(String noteId);

  /// Downloads a PDF from [url] (phones show it in-app). Max 60 MB.
  Future<Uint8List> download(String url);
}

class FirebasePurchasesRepository implements PurchasesRepository {
  /// Functions are looked up lazily (only needed when buying / reading).
  FirebasePurchasesRepository(
    this._db, {
    required FirebaseFunctions Function() functions,
    http.Client? client,
  }) : _functionsOf = functions,
       _client = client ?? http.Client();

  final FirebaseFirestore _db;
  final FirebaseFunctions Function() _functionsOf;
  final http.Client _client;

  static const _maxBytes = 60 * 1024 * 1024;

  @override
  Future<Paged<Purchase>> purchases(String uid, {Object? cursor}) async {
    var q = _db
        .collection(FirestorePaths.entitlements(uid))
        .orderBy(EntitlementFields.purchasedAt, descending: true)
        .limit(PurchasesRepository.pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return (
      items: [
        for (final d in snap.docs)
          Purchase.fromJson({...d.data(), 'noteId': d.id}),
      ],
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == PurchasesRepository.pageSize,
    );
  }

  @override
  Future<Paged<PurchaseOrder>> orders(String uid, {Object? cursor}) async {
    var q = _db
        .collection(FirestoreCollections.orders)
        .where(OrderFields.userId, isEqualTo: uid)
        .orderBy(OrderFields.createdAt, descending: true)
        .limit(PurchasesRepository.pageSize);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return (
      items: [
        for (final d in snap.docs)
          PurchaseOrder.fromJson({...d.data(), 'id': d.id}),
      ],
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == PurchasesRepository.pageSize,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functionsOf()
          .httpsCallable(name)
          .call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw PurchaseException(PurchaseFailure.fromCode(e.code, e.message));
    } on TimeoutException {
      throw const PurchaseException(PurchaseFailure.network);
    }
  }

  @override
  Future<CheckoutOrder> createOrder(String noteId) async =>
      CheckoutOrder.fromJson(
        await _call(PaymentFunctions.createOrder, {'noteId': noteId}),
      );

  @override
  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) => _call(PaymentFunctions.verifyPayment, {
    'orderId': orderId,
    'paymentId': paymentId,
    'signature': signature,
  });

  @override
  Future<String> noteFileUrl(String noteId) async =>
      (await _call(PaymentFunctions.getNoteFileUrl, {'noteId': noteId}))['url']
          as String;

  @override
  Future<Uint8List> download(String url) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse(url));
    } on Exception {
      throw const PurchaseException(PurchaseFailure.network);
    }
    if (res.statusCode != 200 || res.bodyBytes.length > _maxBytes) {
      throw const PurchaseException(PurchaseFailure.unknown);
    }
    return res.bodyBytes;
  }
}

@Riverpod(keepAlive: true)
PurchasesRepository purchasesRepository(Ref ref) => FirebasePurchasesRepository(
  ref.watch(firestoreProvider),
  functions: () => ref.read(functionsProvider),
);
