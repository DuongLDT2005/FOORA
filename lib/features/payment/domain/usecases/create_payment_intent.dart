import '../entities/payment_transaction.dart';
import '../repositories/payment_repository.dart';

class CreatePaymentIntent {
  const CreatePaymentIntent(this.repository);

  final PaymentRepository repository;

  Future<PaymentTransaction> call(String membershipId) {
    return repository.createPaymentOrder(membershipId);
  }
}
