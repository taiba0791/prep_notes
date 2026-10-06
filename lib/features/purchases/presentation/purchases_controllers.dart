import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../data/models/access.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/purchases_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../notes/presentation/browse_providers.dart';
import '../data/payment_service.dart';
import '../domain/purchase_failure.dart';

part 'purchases_controllers.g.dart';

// ── Checkout ───────────────────────────────────────────────

/// What is being bought. Used as the checkout provider key ("note:ID",
/// "bundle:SEMESTER", "room:m1") so it works as a URL-friendly string.
enum CheckoutKind { note, bundle, room }

class CheckoutTarget {
  const CheckoutTarget(this.kind, this.id);

  factory CheckoutTarget.parse(String key) {
    final i = key.indexOf(':');
    return CheckoutTarget(
      CheckoutKind.values.byName(key.substring(0, i)),
      key.substring(i + 1),
    );
  }

  final CheckoutKind kind;

  /// noteId, semesterId or Room plan key (m1 | m3 | m6).
  final String id;

  String get key => '${kind.name}:$id';
}

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

/// create (server sets the price) → Razorpay window → verify (server).
@riverpod
class CheckoutController extends _$CheckoutController {
  @override
  CheckoutState build(String targetKey) =>
      const CheckoutState(CheckoutStep.ready);

  CheckoutTarget get target => CheckoutTarget.parse(targetKey);

  /// Safe to tap twice: ignored while a payment is in progress.
  Future<void> pay({
    required String description,
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
      final PaymentOutcome outcome;
      final t = target;
      if (t.kind == CheckoutKind.room) {
        final sub = await repo.createRoomSubscription(t.id);
        if (!ref.mounted) return;
        state = const CheckoutState(CheckoutStep.paying);
        outcome = await payments.subscribe(
          sub,
          name: AppStrings.appName,
          description: description,
          themeColor: themeColor,
        );
      } else {
        final order = t.kind == CheckoutKind.bundle
            ? await repo.createBundleOrder(t.id)
            : await repo.createOrder(t.id);
        if (!ref.mounted) return;
        state = const CheckoutState(CheckoutStep.paying);
        outcome = await payments.pay(
          order,
          name: AppStrings.appName,
          description: description,
          themeColor: themeColor,
        );
      }
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
          if (t.kind == CheckoutKind.room) {
            await repo.verifyRoomSubscription(
              subscriptionId: outcome.subscriptionId,
              paymentId: outcome.paymentId,
              signature: outcome.signature,
            );
          } else {
            await repo.verifyPayment(
              orderId: outcome.orderId,
              paymentId: outcome.paymentId,
              signature: outcome.signature,
            );
          }
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
    refreshAccess(ref.invalidate);
  }

  /// "Try again" after a failure.
  void reset() {
    if (!state.isBusy) state = const CheckoutState(CheckoutStep.ready);
  }
}

/// Re-reads everything that depends on what the student has paid for.
/// Pass `ref.invalidate` (works with Ref and WidgetRef).
void refreshAccess(void Function(ProviderOrFamily provider) invalidate) {
  for (final p in <ProviderOrFamily>[
    noteAccessProvider,
    myPurchasesProvider,
    myOrdersProvider,
    myBundlesProvider,
    semesterBundleProvider,
    roomAccessProvider,
    roomSubscriptionProvider,
  ]) {
    invalidate(p);
  }
}

// ── Bundles, Room access, subscription ─────────────────────

@riverpod
Future<List<SemesterBundle>> myBundles(Ref ref) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return const [];
  return ref.watch(purchasesRepositoryProvider).bundles(uid);
}

/// The student's bundle for [semesterId] (active or expired), if any.
@riverpod
Future<SemesterBundle?> semesterBundle(Ref ref, String semesterId) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return null;
  return ref.watch(purchasesRepositoryProvider).bundle(uid, semesterId);
}

@riverpod
Future<RoomAccess> roomAccess(Ref ref) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return RoomAccess.closed;
  return ref.watch(purchasesRepositoryProvider).roomAccess(uid);
}

@riverpod
Future<RoomSubscription?> roomSubscription(Ref ref) async {
  final uid = ref.watch(authSessionProvider.select((s) => s.value?.uid));
  if (uid == null) return null;
  return ref.watch(purchasesRepositoryProvider).roomSubscription(uid);
}

@riverpod
Future<List<RoomPlan>> roomPlans(Ref ref) =>
    ref.watch(purchasesRepositoryProvider).roomPlans();

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
