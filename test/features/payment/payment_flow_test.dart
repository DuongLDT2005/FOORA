import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/payment/data/models/payment_transaction_model.dart';
import 'package:foora/features/payment/domain/entities/payment_transaction.dart';
import 'package:foora/features/payment/domain/repositories/payment_repository.dart';
import 'package:foora/features/payment/domain/usecases/cancel_pending_payment.dart';
import 'package:foora/features/payment/domain/usecases/create_payment_intent.dart';
import 'package:foora/features/payment/domain/usecases/watch_payment.dart';
import 'package:foora/features/payment/presentation/providers/payment_provider.dart';

void main() {
  group('PaymentTransactionModel', () {
    test('maps the Cas schema and safe pending fallback', () {
      final model = PaymentTransactionModel.fromJson({
        'paymentId': 'payment-1',
        'membershipId': 'premium',
        'amount': 29000,
        'provider': 'cas',
        'referenceNumber': 'FOORAABC',
        'status': 'requires_review',
        'createdAt': '2026-01-01T00:00:00Z',
        'expiresAt': '2026-01-01T00:15:00Z',
      });

      expect(model.status, PaymentStatus.requiresReview);
      expect(model.referenceNumber, 'FOORAABC');
      expect(model.expiresAt, DateTime.utc(2026, 1, 1, 0, 15));
    });

    test('maps legacy transaction fields without treating unknown as paid', () {
      final model = PaymentTransactionModel.fromJson({
        'id': 'legacy',
        'membershipId': 'premium',
        'amount': 29000,
        'platform': 'android',
        'transactionId': 'store-transaction',
        'status': 'unexpected',
      });

      expect(model.provider, 'android');
      expect(model.providerTransactionId, 'store-transaction');
      expect(model.status, PaymentStatus.pending);
    });
  });

  test(
    'controller only completes after the watched backend state completes',
    () async {
      final repository = _FakePaymentRepository();
      final controller = PaymentController(
        CreatePaymentIntent(repository),
        WatchPayment(repository),
        CancelPendingPayment(repository),
      );

      final created = await controller.createOrder('premium');
      expect(created?.status, PaymentStatus.pending);
      expect(controller.state.phase, PaymentFlowPhase.awaitingPayment);

      repository.emit(_payment(status: PaymentStatus.completed));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.phase, PaymentFlowPhase.completed);
      controller.dispose();
      await repository.dispose();
    },
  );
}

PaymentTransaction _payment({PaymentStatus status = PaymentStatus.pending}) {
  final now = DateTime.utc(2026);
  return PaymentTransaction(
    id: 'payment-1',
    membershipId: 'premium',
    amount: 29000,
    status: status,
    referenceNumber: 'FOORAABC',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakePaymentRepository implements PaymentRepository {
  final _controller = StreamController<PaymentTransaction>.broadcast();

  void emit(PaymentTransaction payment) => _controller.add(payment);

  Future<void> dispose() => _controller.close();

  @override
  Future<void> cancelPendingPayment(String paymentId) async {}

  @override
  Future<PaymentTransaction> createPaymentOrder(String membershipId) async {
    return _payment();
  }

  @override
  Future<List<PaymentTransaction>> getPaymentHistory() async => [];

  @override
  Stream<PaymentTransaction> watchPayment(String paymentId) {
    return _controller.stream;
  }
}
