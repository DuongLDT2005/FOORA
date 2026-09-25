import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/payment_remote_datasource.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/entities/payment_transaction.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/usecases/cancel_pending_payment.dart';
import '../../domain/usecases/create_payment_intent.dart';
import '../../domain/usecases/get_payment_history.dart';
import '../../domain/usecases/watch_payment.dart';

final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>((
  ref,
) {
  return PaymentRemoteDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(
    remoteDataSource: ref.watch(paymentRemoteDataSourceProvider),
  );
});

final createPaymentIntentProvider = Provider<CreatePaymentIntent>((ref) {
  return CreatePaymentIntent(ref.watch(paymentRepositoryProvider));
});

final watchPaymentUseCaseProvider = Provider<WatchPayment>((ref) {
  return WatchPayment(ref.watch(paymentRepositoryProvider));
});

final getPaymentHistoryUseCaseProvider = Provider<GetPaymentHistory>((ref) {
  return GetPaymentHistory(ref.watch(paymentRepositoryProvider));
});

final cancelPendingPaymentUseCaseProvider = Provider<CancelPendingPayment>((
  ref,
) {
  return CancelPendingPayment(ref.watch(paymentRepositoryProvider));
});

final paymentHistoryProvider =
    FutureProvider.autoDispose<List<PaymentTransaction>>((ref) {
      return ref.watch(getPaymentHistoryUseCaseProvider)();
    });

enum PaymentFlowPhase {
  idle,
  creatingOrder,
  awaitingPayment,
  completed,
  expired,
  cancelled,
  requiresReview,
  failed,
}

class PaymentFlowState {
  const PaymentFlowState({
    this.phase = PaymentFlowPhase.idle,
    this.payment,
    this.message,
    this.retryable = false,
  });

  final PaymentFlowPhase phase;
  final PaymentTransaction? payment;
  final String? message;
  final bool retryable;

  PaymentFlowState copyWith({
    PaymentFlowPhase? phase,
    PaymentTransaction? payment,
    String? message,
    bool? retryable,
  }) {
    return PaymentFlowState(
      phase: phase ?? this.phase,
      payment: payment ?? this.payment,
      message: message,
      retryable: retryable ?? this.retryable,
    );
  }
}

class PaymentController extends StateNotifier<PaymentFlowState> {
  PaymentController(
    this._createPayment,
    this._watchPayment,
    this._cancelPayment,
  ) : super(const PaymentFlowState());

  final CreatePaymentIntent _createPayment;
  final WatchPayment _watchPayment;
  final CancelPendingPayment _cancelPayment;
  StreamSubscription<PaymentTransaction>? _subscription;
  bool _isSubmitting = false;

  Future<PaymentTransaction?> createOrder(String membershipId) async {
    if (_isSubmitting) return state.payment;
    _isSubmitting = true;
    state = const PaymentFlowState(phase: PaymentFlowPhase.creatingOrder);
    try {
      final payment = await _createPayment(membershipId);
      _applyPayment(payment);
      await watch(payment.id);
      return payment;
    } catch (error) {
      state = PaymentFlowState(
        phase: PaymentFlowPhase.failed,
        message: 'Không thể xử lý giao dịch. Vui lòng thử lại.',
        retryable: true,
      );
      return null;
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> watch(String paymentId) async {
    await _subscription?.cancel();
    _subscription = _watchPayment(paymentId).listen(
      _applyPayment,
      onError: (Object error, StackTrace stackTrace) {
        state = PaymentFlowState(
          phase: PaymentFlowPhase.failed,
          payment: state.payment,
          message: 'Không thể xử lý giao dịch. Vui lòng thử lại.',
          retryable: true,
        );
      },
    );
  }

  Future<void> cancel() async {
    final payment = state.payment;
    if (payment == null || payment.status != PaymentStatus.pending) return;
    try {
      await _cancelPayment(payment.id);
    } catch (error) {
      state = PaymentFlowState(
        phase: PaymentFlowPhase.failed,
        payment: payment,
        message: 'Không thể xử lý giao dịch. Vui lòng thử lại.',
        retryable: true,
      );
    }
  }

  void _applyPayment(PaymentTransaction payment) {
    state = PaymentFlowState(
      phase: switch (payment.status) {
        PaymentStatus.pending => PaymentFlowPhase.awaitingPayment,
        PaymentStatus.completed => PaymentFlowPhase.completed,
        PaymentStatus.expired => PaymentFlowPhase.expired,
        PaymentStatus.cancelled => PaymentFlowPhase.cancelled,
        PaymentStatus.requiresReview => PaymentFlowPhase.requiresReview,
        PaymentStatus.failed => PaymentFlowPhase.failed,
      },
      payment: payment,
      message: payment.status == PaymentStatus.failed
          ? 'Khong the xu ly giao dich.'
          : null,
      retryable: payment.status == PaymentStatus.failed,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final paymentControllerProvider =
    StateNotifierProvider.autoDispose<PaymentController, PaymentFlowState>((
      ref,
    ) {
      return PaymentController(
        ref.watch(createPaymentIntentProvider),
        ref.watch(watchPaymentUseCaseProvider),
        ref.watch(cancelPendingPaymentUseCaseProvider),
      );
    });
