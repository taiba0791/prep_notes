import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/providers/firebase_providers.dart';
import 'package:prepnotes/data/repositories/purchases_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';
import 'package:prepnotes/features/purchases/domain/purchase_failure.dart';
import 'package:prepnotes/features/purchases/presentation/purchases_controllers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_purchases.dart';

void main() {
  group('PurchaseFailure.fromCode', () {
    test('maps server codes to friendly messages', () {
      expect(
        PurchaseFailure.fromCode('already-exists'),
        PurchaseFailure.alreadyOwned,
      );
      expect(
        PurchaseFailure.fromCode('permission-denied', 'not-purchased'),
        PurchaseFailure.notPurchased,
      );
      expect(
        PurchaseFailure.fromCode('permission-denied'),
        PurchaseFailure.notVerified,
      );
      expect(
        PurchaseFailure.fromCode('resource-exhausted'),
        PurchaseFailure.tooMany,
      );
      expect(PurchaseFailure.fromCode('unavailable'), PurchaseFailure.busy);
      expect(PurchaseFailure.fromCode('weird'), PurchaseFailure.unknown);
      for (final f in PurchaseFailure.values) {
        expect(f.message, isNotEmpty);
      }
    });
  });

  group('FirebasePurchasesRepository (reads)', () {
    late FakeFirebaseFirestore db;
    late FirebasePurchasesRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirebasePurchasesRepository(
        db,
        functions: () => throw StateError('not used'),
      );
    });

    test('purchases: newest first, note id from the document', () async {
      for (var i = 1; i <= 3; i++) {
        await db.doc(FirestorePaths.entitlement('alice', 'n$i')).set({
          EntitlementFields.orderId: 'order_$i',
          EntitlementFields.purchasedAt: Timestamp.fromMillisecondsSinceEpoch(
            i * 1000,
          ),
          EntitlementFields.pricePaid: 4900,
          EntitlementFields.title: 'Note $i',
        });
      }
      await db.doc(FirestorePaths.entitlement('bob', 'x')).set({
        EntitlementFields.purchasedAt: Timestamp.now(),
      });
      final page = await repo.purchases('alice');
      expect(page.items.map((p) => p.noteId), ['n3', 'n2', 'n1']);
      expect(page.items.first.title, 'Note 3');
      expect(page.items.first.toNote().id, 'n3');
      expect(page.hasMore, isFalse);
    });

    test('orders: only mine, newest first, paginated', () async {
      for (var i = 1; i <= PurchasesRepository.pageSize + 2; i++) {
        await db.doc(FirestorePaths.order('order_$i')).set({
          OrderFields.userId: 'alice',
          OrderFields.noteIds: ['n$i'],
          OrderFields.noteTitles: ['Note $i'],
          OrderFields.amount: 4900,
          OrderFields.status: OrderStatus.paid,
          OrderFields.createdAt: Timestamp.fromMillisecondsSinceEpoch(i * 1000),
        });
      }
      await db.doc(FirestorePaths.order('order_bob')).set({
        OrderFields.userId: 'bob',
        OrderFields.createdAt: Timestamp.now(),
      });
      final first = await repo.orders('alice');
      expect(first.items, hasLength(PurchasesRepository.pageSize));
      expect(first.items.first.id, 'order_${PurchasesRepository.pageSize + 2}');
      expect(first.hasMore, isTrue);
      expect(first.items.every((o) => o.userId == 'alice'), isTrue);
      // Page 2 isn't checked here: fake_cloud_firestore gets
      // startAfterDocument wrong on descending queries. Same cursor code as
      // the notes lists, which were verified on the emulator in Phase 3.
    });
  });

  group('CheckoutController', () {
    late FakePurchasesRepository repo;
    late FakePaymentService payments;
    late ProviderContainer container;

    ProviderContainer make({bool supported = true}) {
      repo = FakePurchasesRepository();
      payments = FakePaymentService(isSupported: supported);
      final c = ProviderContainer(
        overrides: [
          purchasesRepositoryProvider.overrideWithValue(repo),
          paymentServiceProvider.overrideWithValue(payments),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(const AuthSession(uid: 'alice')),
          ),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(checkoutControllerProvider('note:n1'), (_, _) {});
      return c;
    }

    CheckoutState state() =>
        container.read(checkoutControllerProvider('note:n1'));
    Future<void> pay() => container
        .read(checkoutControllerProvider('note:n1').notifier)
        .pay(description: 'Maths', themeColor: '#8f1d3f');

    test('success: create → pay → verify on the server', () async {
      container = make();
      await pay();
      expect(state().step, CheckoutStep.success);
      expect(repo.calls, ['createOrder:n1', 'verify:order_1:pay_1:sig']);
      expect(payments.opened.single.amount, 14900);
    });

    test('closing the window = cancelled, nothing verified', () async {
      container = make();
      payments.outcome = const PaymentDismissed();
      await pay();
      expect(state().step, CheckoutStep.failed);
      expect(state().message, AppStrings.paymentCancelled);
      expect(repo.calls, ['createOrder:n1']);

      // "Try again" works.
      container.read(checkoutControllerProvider('note:n1').notifier).reset();
      payments.outcome = null;
      await pay();
      expect(state().step, CheckoutStep.success);
    });

    test('Razorpay failure shows its reason', () async {
      container = make();
      payments.outcome = const PaymentFailed('Card declined');
      await pay();
      expect(state().message, 'Card declined');
    });

    test('server rejects the payment → friendly message', () async {
      container = make();
      repo.verifyFails = PurchaseFailure.notVerified;
      await pay();
      expect(state().step, CheckoutStep.failed);
      expect(state().message, AppStrings.payErrNotVerified);
    });

    test('already owned counts as success', () async {
      container = make();
      repo.createFails = PurchaseFailure.alreadyOwned;
      await pay();
      expect(state().step, CheckoutStep.success);
      expect(payments.opened, isEmpty);
    });

    test('double tap creates only one order', () async {
      container = make();
      repo.createGate = Completer<void>();
      final a = pay();
      final b = pay();
      expect(state().step, CheckoutStep.creating);
      repo.createGate!.complete();
      await Future.wait([a, b]);
      expect(
        repo.calls.where((c) => c.startsWith('createOrder')),
        hasLength(1),
      );
    });

    test('no payment window on this platform → web-only message', () async {
      container = make(supported: false);
      await pay();
      expect(state().message, AppStrings.paymentsWebOnly);
      expect(repo.calls, isEmpty);
    });
  });

  test('FirebaseFunctionsException codes become PurchaseExceptions', () {
    final e = FirebaseFunctionsException(
      code: 'resource-exhausted',
      message: 'x',
    );
    expect(
      PurchaseFailure.fromCode(e.code, e.message),
      PurchaseFailure.tooMany,
    );
  });
}
