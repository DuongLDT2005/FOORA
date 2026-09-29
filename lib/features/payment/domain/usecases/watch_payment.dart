import '../entities/payment_transaction.dart';
import '../repositories/payment_repository.dart';

class WatchPayment {
  const WatchPayment(this.repository);

  final PaymentRepository repository;

  Stream<PaymentTransaction> call(String paymentId) {
    return repository.watchPayment(paymentId);
  }
}
