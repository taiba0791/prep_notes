import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../../data/models/purchase.dart';
import 'payment_service.dart';

/// Web: Razorpay Checkout JS (`<script src="https://checkout.razorpay.com/v1/checkout.js">`
/// in web/index.html).
PaymentService createPaymentService() => const RazorpayWebPaymentService();

@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

class RazorpayWebPaymentService implements PaymentService {
  const RazorpayWebPaymentService();

  @override
  bool get isSupported => globalContext.has('Razorpay');

  @override
  Future<PaymentOutcome> pay(
    CheckoutOrder order, {
    required String name,
    required String description,
    required String themeColor,
  }) => _open({
    'key': order.keyId,
    'amount': order.amount,
    'currency': order.currency,
    'order_id': order.orderId,
    'name': name,
    'description': description,
    'prefill': {'email': order.email},
    'theme': {'color': themeColor},
  });

  @override
  Future<PaymentOutcome> subscribe(
    CheckoutSubscription subscription, {
    required String name,
    required String description,
    required String themeColor,
  }) => _open({
    'key': subscription.keyId,
    'subscription_id': subscription.subscriptionId,
    'name': name,
    'description': description,
    'prefill': {'email': subscription.email},
    'theme': {'color': themeColor},
  });

  /// Opens Razorpay Checkout and waits for success, failure or close.
  Future<PaymentOutcome> _open(Map<String, Object?> settings) {
    final done = Completer<PaymentOutcome>();
    void finish(PaymentOutcome o) {
      if (!done.isCompleted) done.complete(o);
    }

    if (!isSupported) {
      // Script blocked (ad blocker) or offline.
      return Future.value(const PaymentFailed('checkout-unavailable'));
    }

    final options = settings.jsify()! as JSObject;
    options['handler'] = ((JSObject r) {
      String field(String k) => (r[k] as JSString?)?.toDart ?? '';
      finish(
        PaymentSucceeded(
          orderId: field('razorpay_order_id'),
          subscriptionId: field('razorpay_subscription_id'),
          paymentId: field('razorpay_payment_id'),
          signature: field('razorpay_signature'),
        ),
      );
    }).toJS;

    // Razorpay keeps its window open after a failure so the student can try
    // another method; we remember the last reason and report it on close.
    String? lastFailure;
    final modal = JSObject();
    modal['ondismiss'] = (() {
      final reason = lastFailure;
      finish(reason == null ? const PaymentDismissed() : PaymentFailed(reason));
    }).toJS;
    options['modal'] = modal;

    final checkout = _Razorpay(options);
    checkout.on(
      'payment.failed',
      ((JSObject e) {
        final error = e['error'] as JSObject?;
        lastFailure = (error?['description'] as JSString?)?.toDart;
      }).toJS,
    );
    checkout.open();
    return done.future;
  }
}
