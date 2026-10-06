import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/purchases_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../notes/presentation/browse_providers.dart';
import '../data/payment_service.dart';
import '../domain/purchase_failure.dart';

part 'purchases_controllers.g.dart';

// ── Checkout ───────────────────────────────────────────────

enum CheckoutStep { ready, creating, paying, verifying, success, failed }

class CheckoutState {
  const CheckoutState(this.step, {this.message});

  final CheckoutStep step;

  /// Why it failed (shown to the student).
  final String? message;

  bool get isBusy =>
      step == CheckoutStep.creating ||
      step == CheckoutStep.paying ||
      step == CheckoutStep.verifying;
}

/// create order (server) → Razorpay window → verify (server).
@riverpod
class CheckoutController extends _$CheckoutController {
  @override
  CheckoutState build(String noteId) => const CheckoutState(CheckoutStep.ready);

  /// Safe to tap twice: ignored while a payment is in progress.
  Future<void> pay({
    required String noteTitle,
    required String themeColor,
  }) async {
    if (state.isBusy || state.step == CheckoutStep.success) return;
    final repo = ref.read(purchasesRepositoryProvider);
    final payments = ref.read(paymentServiceProvider);

    if (!payments.isSupported) {
      state = const CheckoutState(
        CheckoutStep.failed,
        message: AppStrings.paymentsWebOnly,
      );
      return;
    }

    try {
      state = const CheckoutState(CheckoutStep.creating);
      final order = await repo.createOrder(noteId);
      if (!ref.mounted) return;

      state = const CheckoutState(CheckoutStep.paying);
      final outcome = await payments.pay(
        order,
        name: AppStrings.appName,
        description: noteTitle,
        themeColor: themeColor,
      );
      if (!ref.mounted) return;

      switch (outcome) {
        case PaymentDismissed():
          state = const CheckoutState(
            CheckoutStep.failed,
            message: AppStrings.paymentCancelled,
          );
        case PaymentFailed(:final reason):
          state = CheckoutState(
            CheckoutStep.failed,
            message: reason == 'checkout-unavailable'
                ? AppStrings.payErrBusy
                : reason,
          );
        case PaymentSucceeded():
          state = const CheckoutState(CheckoutStep.verifying);
          await repo.verifyPayment(
            orderId: outcome.orderId,
            paymentId: outcome.paymentId,
            signature: outcome.signature,
          );
          _succeeded();
      }
    } on PurchaseException catch (e) {
      if (!ref.mounted) return;
      if (e.failure == PurchaseFailure.alreadyOwned) {
        _succeeded();
      } else {
        state = CheckoutState(CheckoutStep.failed, message: e.failure.message);
      }
    } on Object catch (e, st) {
      ref.read(errorReporterProvider).recordError(e, st);
      if (ref.mounted) {
        state = const CheckoutState(
          CheckoutStep.failed,
          message: AppStrings.payErrUnknown,
        );
      }
    }
  }

  void _succeeded() {
    if (!ref.mounted) return;
    state = const CheckoutState(CheckoutStep.success);
    ref
      ..invalidate(ownsNoteProvider(noteId))
      ..invalidate(myPurchasesProvider)
      ..invalidate(myOrdersProvider);
  }

  /// "Try again" after a failure.
  void reset() {
    if (!state.isBusy) state = const CheckoutState(CheckoutStep.ready);
  }
}

// ── My Purchases (paginated) ───────────────────────────────

class PagedState<T> {
  const PagedState(
    this.items, {
    this.cursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<T> items;
  final Object? cursor;
  final bool hasMore;
  final bool loadingMore;
}

typedef _Fetch<T> = Future<Paged<T>> Function(
  PurchasesRepository repo,
  String uid,
  Object? c,
);

Future<PagedState<T>> _firstPage<T>(Ref ref, _Fetch<T> fetch) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return PagedState<T>(const []);
  final page = await fetch(ref.watch(purchasesRepositoryProvider), uid, null);
  return PagedState(page.items, cursor: page.cursor, hasMore: page.hasMore);
}

Future<void> _nextPage<T>(
  Ref ref,
  AsyncValue<PagedState<T>> Function() read,
  void Function(AsyncValue<PagedState<T>>) write,
  _Fetch<T> fetch,
) async {
  final current = read().value;
  final uid = ref.read(authSessionProvider).value?.uid;
  if (current == null ||
      !current.hasMore ||
      current.loadingMore ||
      uid == null) {
    return;
  }
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
    final page = await fetch(
      ref.read(purchasesRepositoryProvider),
      uid,
      current.cursor,
    );
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

@riverpod
class MyPurchases extends _$MyPurchases {
  static Future<Paged<Purchase>> _fetch(
    PurchasesRepository r,
    String uid,
    Object? c,
  ) => r.purchases(uid, cursor: c);

  @override
  Future<PagedState<Purchase>> build() => _firstPage(ref, _fetch);

  Future<void> loadMore() =>
      _nextPage(ref, () => state, (s) => state = s, _fetch);
}

@riverpod
class MyOrders extends _$MyOrders {
  static Future<Paged<PurchaseOrder>> _fetch(
    PurchasesRepository r,
    String uid,
    Object? c,
  ) => r.orders(uid, cursor: c);

  @override
  Future<PagedState<PurchaseOrder>> build() => _firstPage(ref, _fetch);

  Future<void> loadMore() =>
      _nextPage(ref, () => state, (s) => state = s, _fetch);
}

// ── Viewer ─────────────────────────────────────────────────

/// No automatic retries: a refusal ("not purchased") won't change by asking
/// again, and every call counts against the server's rate limit. The screen
/// has a Retry button instead.
Duration? _noRetry(int retryCount, Object error) => null;

/// A fresh signed link to the full PDF (expires after ~10 minutes).
@Riverpod(retry: _noRetry)
Future<({String url, DateTime fetchedAt})> noteFileLink(
  Ref ref,
  String noteId,
) async => (
  url: await ref.watch(purchasesRepositoryProvider).noteFileUrl(noteId),
  fetchedAt: DateTime.now(),
);

/// The full PDF, downloaded once for the in-app viewer (phones).
@Riverpod(retry: _noRetry)
Future<Uint8List> noteFileBytes(Ref ref, String noteId) async {
  final link = await ref.watch(noteFileLinkProvider(noteId).future);
  return ref.watch(purchasesRepositoryProvider).download(link.url);
}

/// Shown faintly over paid PDFs on phones.
@riverpod
String viewerWatermark(Ref ref) =>
    ref.watch(authSessionProvider.select((s) => s.value?.email)) ?? '';
