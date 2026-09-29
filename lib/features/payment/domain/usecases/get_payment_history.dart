import '../entities/payment_transaction.dart';
import '../repositories/payment_repository.dart';

class GetPaymentHistory {
  const GetPaymentHistory(this.repository);

  final PaymentRepository repository;

  Future<List<PaymentTransaction>> call() {
    return repository.getPaymentHistory();
  }
}
