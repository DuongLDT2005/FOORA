import '../../domain/entities/payment_transaction.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_datasource.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl({required this.remoteDataSource});

  final PaymentRemoteDataSource remoteDataSource;

  @override
  Future<PaymentTransaction> createPaymentOrder(String membershipId) {
    return remoteDataSource.createPaymentOrder(membershipId);
  }

  @override
  Stream<PaymentTransaction> watchPayment(String paymentId) {
    return remoteDataSource.watchPayment(paymentId);
  }

  @override
  Future<List<PaymentTransaction>> getPaymentHistory() {
    return remoteDataSource.getPaymentHistory();
  }

  @override
  Future<void> cancelPendingPayment(String paymentId) {
    return remoteDataSource.cancelPendingPayment(paymentId);
  }
}
