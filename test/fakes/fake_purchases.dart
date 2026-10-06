import 'dart:async';
import 'dart:typed_data';

import 'package:prepnotes/data/models/access.dart';
import 'package:prepnotes/data/models/purchase.dart';
import 'package:prepnotes/data/repositories/purchases_repository.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';
import 'package:prepnotes/features/purchases/domain/purchase_failure.dart';

/// In-memory PurchasesRepository: records calls, can be told to fail.
class FakePurchasesRepository implements PurchasesRepository {
  final calls = <String>[];
  List<Purchase> owned = [];
  List<PurchaseOrder> orderList = [];
  List<SemesterBundle> bundleList = [];
  RoomAccess access = RoomAccess.closed;
  RoomSubscription? subscription;
  List<RoomPlan> plans = RoomPlan.defaults;
  PurchaseFailure? createFails;
  PurchaseFailure? verifyFails;
  PurchaseFailure? fileFails;

  /// Lets a test hold createOrder open (to check double taps).
  Completer<void>? createGate;

  @override
  Future<Paged<Purchase>> purchases(String uid, {Object? cursor}) async {
    calls.add('purchases:$uid');
    return (items: owned, cursor: null, hasMore: false);
  }

  @override
  Future<Paged<PurchaseOrder>> orders(String uid, {Object? cursor}) async {
    calls.add('orders:$uid');
    return (items: orderList, cursor: null, hasMore: false);
  }

  @override
  Future<CheckoutOrder> createOrder(String noteId) async {
    calls.add('createOrder:$noteId');
    await createGate?.future;
    if (createFails != null) throw PurchaseException(createFails!);
    return const CheckoutOrder(
      orderId: 'order_1',
      amount: 14900,
      currency: 'INR',
      keyId: 'rzp_test_x',
    );
  }

  @override
  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    calls.add('verify:$orderId:$paymentId:$signature');
    if (verifyFails != null) throw PurchaseException(verifyFails!);
  }

  @override
  Future<String> noteFileUrl(String noteId) async {
    calls.add('fileUrl:$noteId');
    if (fileFails != null) throw PurchaseException(fileFails!);
    return 'https://signed.example/$noteId.pdf';
  }

  @override
  Future<Uint8List> download(String url) async => Uint8List(0);

  @override
  Future<CheckoutOrder> createBundleOrder(String semesterId) async {
    calls.add('createBundle:$semesterId');
    if (createFails != null) throw PurchaseException(createFails!);
    return const CheckoutOrder(
      orderId: 'order_b1',
      amount: 89900,
      currency: 'INR',
      keyId: 'rzp_test_x',
    );
  }

  @override
  Future<List<SemesterBundle>> bundles(String uid) async => bundleList;

  @override
  Future<SemesterBundle?> bundle(String uid, String semesterId) async =>
      bundleList.where((b) => b.semesterId == semesterId).firstOrNull;

  @override
  Future<RoomAccess> roomAccess(String uid) async => access;

  @override
  Future<RoomSubscription?> roomSubscription(String uid) async => subscription;

  @override
  Future<List<RoomPlan>> roomPlans() async => plans;

  @override
  Future<CheckoutSubscription> createRoomSubscription(String planKey) async {
    calls.add('createSub:$planKey');
    if (createFails != null) throw PurchaseException(createFails!);
    return const CheckoutSubscription(
      subscriptionId: 'sub_1',
      amount: 14900,
      currency: 'INR',
      keyId: 'rzp_test_x',
      months: 1,
    );
  }

  @override
  Future<void> verifyRoomSubscription({
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    calls.add('verifySub:$subscriptionId:$paymentId:$signature');
    if (verifyFails != null) throw PurchaseException(verifyFails!);
  }

  @override
  Future<void> cancelRoomSubscription() async {
    calls.add('cancelSub');
  }
}

/// Payment window that answers with [outcome].
class FakePaymentService implements PaymentService {
  FakePaymentService({this.outcome, this.isSupported = true});

  PaymentOutcome? outcome;

  @override
  final bool isSupported;

  final opened = <CheckoutOrder>[];

  @override
  Future<PaymentOutcome> pay(
    CheckoutOrder order, {
    required String name,
    required String description,
    required String themeColor,
  }) async {
    opened.add(order);
    return outcome ??
        const PaymentSucceeded(
          orderId: 'order_1',
          paymentId: 'pay_1',
          signature: 'sig',
        );
  }

  final subscribed = <CheckoutSubscription>[];

  @override
  Future<PaymentOutcome> subscribe(
    CheckoutSubscription subscription, {
    required String name,
    required String description,
    required String themeColor,
  }) async {
    subscribed.add(subscription);
    return outcome ??
        const PaymentSucceeded(
          subscriptionId: 'sub_1',
          paymentId: 'pay_s1',
          signature: 'sig',
        );
  }
}
