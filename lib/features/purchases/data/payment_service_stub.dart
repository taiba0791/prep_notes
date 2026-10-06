import '../../../data/models/purchase.dart';
import 'payment_service.dart';

/// Android / iOS / tests: in-app payments are off (buy on the website).
PaymentService createPaymentService() => const UnsupportedPaymentService();

class UnsupportedPaymentService implements PaymentService {
  const UnsupportedPaymentService();

  @override
  bool get isSupported => false;

  @override
  Future<PaymentOutcome> pay(
    CheckoutOrder order, {
    required String name,
    required String description,
    required String themeColor,
  }) async => const PaymentFailed('unsupported');

  @override
  Future<PaymentOutcome> subscribe(
    CheckoutSubscription subscription, {
    required String name,
    required String description,
    required String themeColor,
  }) async => const PaymentFailed('unsupported');
}
