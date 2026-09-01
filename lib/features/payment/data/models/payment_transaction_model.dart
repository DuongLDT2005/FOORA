import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/payment_transaction.dart';

class PaymentTransactionModel extends PaymentTransaction {
  const PaymentTransactionModel({
    required super.id,
    required super.subscriptionId,
    required super.membershipId,
    required super.amount,
    super.currency = 'VND',
    required super.platform,
    required super.productId,
    required super.transactionId,
    super.status = PaymentStatus.completed,
    required super.createdAt,
  });

  factory PaymentTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PaymentTransactionModel.fromJson(data, id: doc.id);
  }

  factory PaymentTransactionModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return PaymentTransactionModel(
      id: id ?? json['id'] as String? ?? json['paymentId'] as String? ?? '',
      subscriptionId: json['subscriptionId'] as String? ?? '',
      membershipId: json['membershipId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'VND',
      platform: AppPlatform.fromString(json['platform'] as String?),
      productId: json['productId'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
      status: PaymentStatus.fromString(json['status'] as String?),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subscriptionId': subscriptionId,
      'membershipId': membershipId,
      'amount': amount,
      'currency': currency,
      'platform': platform.value,
      'productId': productId,
      'transactionId': transactionId,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriptionId': subscriptionId,
      'membershipId': membershipId,
      'amount': amount,
      'currency': currency,
      'platform': platform.value,
      'productId': productId,
      'transactionId': transactionId,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}
