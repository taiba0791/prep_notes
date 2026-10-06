import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/purchase.dart';
import 'payment_service_stub.dart'
    if (dart.library.js_interop) 'payment_service_web.dart';

part 'payment_service.g.dart';

/// What happened in the Razorpay window.
sealed class PaymentOutcome {
  const PaymentOutcome();
}

/// Razorpay says it's paid. The SERVER still has to verify [signature].
class PaymentSucceeded extends PaymentOutcome {
  const PaymentSucceeded({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

/// The student closed the window without paying.
class PaymentDismissed extends PaymentOutcome {
  const PaymentDismissed();
}

/// Razorpay reported a failure (e.g. card declined).
class PaymentFailed extends PaymentOutcome {
  const PaymentFailed(this.reason);

  final String reason;
}

/// Opens the payment window for an order created by the server.
///
/// Web: Razorpay Checkout JS (web/index.html loads it).
/// Android/iOS: not available yet — the app sends buyers to the website
/// (Play Store rules for digital goods); see [isSupported].
abstract interface class PaymentService {
  bool get isSupported;

  Future<PaymentOutcome> pay(
    CheckoutOrder order, {
    required String name,
    required String description,
    required String themeColor,
  });
}

@Riverpod(keepAlive: true)
PaymentService paymentService(Ref ref) => createPaymentService();

/// Can students buy inside this app? Website: yes. Android/iOS: not for now
/// — they get a "Buy on website" button instead (store rules for digital
/// goods). To allow it later, add razorpay_flutter and return true here.
@Riverpod(keepAlive: true)
bool buyInApp(Ref ref) => kIsWeb;
