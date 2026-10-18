import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foora/core/constants/firestore_constants.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/payment_transaction_model.dart';

/// Contract for Premium payment operations (bank-transfer QR via CAS gateway).
abstract class PaymentRemoteDataSource {
  /// Creates a payment order for a plan and returns its QR / transfer details.
  Future<PaymentTransactionModel> createPaymentOrder(String membershipId);

  /// Streams a payment document so the UI updates when the webhook confirms it.
  Stream<PaymentTransactionModel> watchPayment(String paymentId);

  /// Loads the current user's past transactions.
  Future<List<PaymentTransactionModel>> getPaymentHistory();

  /// Cancels a payment that has not been paid yet.
  Future<void> cancelPendingPayment(String paymentId);
}

/// Cloud Functions + Firestore implementation of [PaymentRemoteDataSource].
class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  PaymentRemoteDataSourceImpl(this._auth, this._firestore, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String get _userId {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Authentication is required for payment operations.');
    }
    return userId;
  }

  CollectionReference<Map<String, dynamic>> get _payments => _firestore
      .collection(FirestoreConstants.users)
      .doc(_userId)
      .collection(FirestoreConstants.payments);

  /// Calls the `createCasPaymentOrder` callable; the server computes the amount
  /// so the client can never tamper with the price.
  @override
  Future<PaymentTransactionModel> createPaymentOrder(
    String membershipId,
  ) async {
    try {
      final callable = _functions.httpsCallable(
        'createCasPaymentOrder',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final result = await callable.call(<String, dynamic>{
        'membershipId': membershipId,
      });
      final envelope = Map<String, dynamic>.from(result.data as Map);
      if (envelope['success'] != true || envelope['data'] is! Map) {
        throw ServerException(
          envelope['error'] as String? ?? 'Không thể tạo giao dịch thanh toán.',
        );
      }
      return PaymentTransactionModel.fromJson(
        Map<String, dynamic>.from(envelope['data'] as Map),
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsException(error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException('Không thể tạo giao dịch thanh toán: $error');
    }
  }

  /// Listens to `payments/{paymentId}`.
  @override
  Stream<PaymentTransactionModel> watchPayment(String paymentId) {
    return _payments.doc(paymentId).snapshots().map((document) {
      if (!document.exists) {
        throw StateError('Payment not found.');
      }
      return PaymentTransactionModel.fromFirestore(document);
    });
  }

  /// Queries the user's payments ordered by creation date.
  @override
  Future<List<PaymentTransactionModel>> getPaymentHistory() async {
    final snapshot = await _payments
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snapshot.docs
        .map(PaymentTransactionModel.fromFirestore)
        .toList(growable: false);
  }

  /// Calls the `cancelCasPaymentOrder` callable.
  @override
  Future<void> cancelPendingPayment(String paymentId) async {
    try {
      final result = await _functions
          .httpsCallable('cancelCasPaymentOrder')
          .call(<String, dynamic>{'paymentId': paymentId});
      final envelope = Map<String, dynamic>.from(result.data as Map);
      if (envelope['success'] != true) {
        throw ServerException(
          envelope['error'] as String? ?? 'Không thể hủy giao dịch.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsException(error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException('Không thể hủy giao dịch: $error');
    }
  }

  /// Converts Cloud Functions error codes into readable [ServerException]s.
  ServerException _mapFunctionsException(FirebaseFunctionsException error) {
    final fallback = switch (error.code) {
      'unauthenticated' =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      'permission-denied' => 'Bạn không có quyền thực hiện giao dịch này.',
      'not-found' => 'Không tìm thấy gói thành viên.',
      'failed-precondition' => 'Gói thành viên hiện chưa thể được thanh toán.',
      'unavailable' || 'deadline-exceeded' =>
        'Dịch vụ thanh toán đang tạm gián đoạn. Vui lòng thử lại.',
      'aborted' =>
        'Giao dịch đang được khởi tạo. Vui lòng thử lại sau ít giây.',
      _ => 'Không thể xử lý giao dịch. Vui lòng thử lại.',
    };
    final providerMessage = error.message?.trim();
    final canShowProviderMessage = {
      'invalid-argument',
      'permission-denied',
      'not-found',
      'failed-precondition',
    }.contains(error.code);
    return ServerException(
      canShowProviderMessage &&
              providerMessage != null &&
              providerMessage.isNotEmpty
          ? providerMessage
          : fallback,
      error.code,
    );
  }
}
