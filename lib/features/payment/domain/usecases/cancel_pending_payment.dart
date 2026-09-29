import '../repositories/payment_repository.dart';

class CancelPendingPayment {
  const CancelPendingPayment(this.repository);

  final PaymentRepository repository;

  Future<void> call(String paymentId) {
    return repository.cancelPendingPayment(paymentId);
  }
}
