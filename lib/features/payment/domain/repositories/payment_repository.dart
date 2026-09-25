import '../entities/payment_transaction.dart';

abstract class PaymentRepository {
  Future<PaymentTransaction> createPaymentOrder(String membershipId);
  Stream<PaymentTransaction> watchPayment(String paymentId);
  Future<List<PaymentTransaction>> getPaymentHistory();
  Future<void> cancelPendingPayment(String paymentId);
}
