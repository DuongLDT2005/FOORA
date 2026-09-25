import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foora/core/constants/firestore_constants.dart';

import '../models/payment_transaction_model.dart';

abstract class PaymentRemoteDataSource {
  Future<PaymentTransactionModel> createPaymentOrder(String membershipId);
  Stream<PaymentTransactionModel> watchPayment(String paymentId);
  Future<List<PaymentTransactionModel>> getPaymentHistory();
  Future<void> cancelPendingPayment(String paymentId);
}

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

  @override
  Future<PaymentTransactionModel> createPaymentOrder(
    String membershipId,
  ) async {
    final result = await _functions.httpsCallable('createCasPaymentOrder').call(
      <String, dynamic>{'membershipId': membershipId},
    );
    final envelope = Map<String, dynamic>.from(result.data as Map);
    if (envelope['success'] != true || envelope['data'] is! Map) {
      throw StateError(
        envelope['error'] as String? ?? 'Cannot create payment.',
      );
    }
    return PaymentTransactionModel.fromJson(
      Map<String, dynamic>.from(envelope['data'] as Map),
    );
  }

  @override
  Stream<PaymentTransactionModel> watchPayment(String paymentId) {
    return _payments.doc(paymentId).snapshots().map((document) {
      if (!document.exists) {
        throw StateError('Payment not found.');
      }
      return PaymentTransactionModel.fromFirestore(document);
    });
  }

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

  @override
  Future<void> cancelPendingPayment(String paymentId) async {
    final result = await _functions.httpsCallable('cancelCasPaymentOrder').call(
      <String, dynamic>{'paymentId': paymentId},
    );
    final envelope = Map<String, dynamic>.from(result.data as Map);
    if (envelope['success'] != true) {
      throw StateError(
        envelope['error'] as String? ?? 'Cannot cancel payment.',
      );
    }
  }
}
