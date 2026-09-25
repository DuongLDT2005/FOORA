import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/payment_transaction.dart';

class PaymentTransactionModel extends PaymentTransaction {
  const PaymentTransactionModel({
    required super.id,
    required super.membershipId,
    required super.amount,
    super.currency,
    super.provider,
    super.providerRequestId,
    super.referenceNumber,
    super.providerTransactionId,
    super.subscriptionId,
    super.qrCode,
    super.virtualAccountNumber,
    super.description,
    super.status,
    super.expiresAt,
    super.paidAt,
    super.cancelledAt,
    super.reviewReason,
    required super.createdAt,
    super.updatedAt,
    super.platform,
    super.productId,
    super.transactionId,
  });

  factory PaymentTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return PaymentTransactionModel.fromJson(
      document.data() ?? const <String, dynamic>{},
      id: document.id,
    );
  }

  factory PaymentTransactionModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    final createdAt =
        _parseDateTime(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final legacyPlatform = AppPlatform.fromString(json['platform'] as String?);
    return PaymentTransactionModel(
      id: id ?? json['id'] as String? ?? json['paymentId'] as String? ?? '',
      membershipId: json['membershipId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'VND',
      provider:
          json['provider'] as String? ?? json['platform'] as String? ?? 'cas',
      providerRequestId: json['providerRequestId'] as String? ?? '',
      referenceNumber: json['referenceNumber'] as String? ?? '',
      providerTransactionId:
          json['providerTransactionId'] as String? ??
          json['transactionId'] as String? ??
          '',
      subscriptionId: json['subscriptionId'] as String? ?? '',
      qrCode: json['qrCode'] as String? ?? '',
      virtualAccountNumber: json['virtualAccountNumber'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: PaymentStatus.fromString(json['status'] as String?),
      expiresAt: _parseDateTime(json['expiresAt']),
      paidAt: _parseDateTime(json['paidAt']),
      cancelledAt: _parseDateTime(json['cancelledAt']),
      reviewReason: json['reviewReason'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updatedAt']) ?? createdAt,
      platform: legacyPlatform,
      productId: json['productId'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriptionId': subscriptionId,
      'membershipId': membershipId,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'providerRequestId': providerRequestId,
      'referenceNumber': referenceNumber,
      'providerTransactionId': providerTransactionId,
      'qrCode': qrCode,
      'virtualAccountNumber': virtualAccountNumber,
      'description': description,
      'status': status.value,
      'expiresAt': expiresAt?.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'reviewReason': reviewReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (productId.isNotEmpty) 'productId': productId,
      if (transactionId.isNotEmpty) 'transactionId': transactionId,
      if (provider != 'cas') 'platform': platform.value,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
