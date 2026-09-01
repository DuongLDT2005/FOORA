import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing an In-App Purchase transaction.
/// Strictly mapped to users/{userId}/payments/{paymentId} in docs/DATABASE.md
@immutable
class PaymentTransaction {
  final String id;
  final String subscriptionId;
  final String membershipId; // Foreign key to memberships/{membershipId}
  final double amount;
  final String currency; // 'VND'
  final AppPlatform platform;
  final String productId;
  final String transactionId;
  final PaymentStatus status;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.subscriptionId,
    required this.membershipId,
    required this.amount,
    this.currency = 'VND',
    required this.platform,
    required this.productId,
    required this.transactionId,
    this.status = PaymentStatus.completed,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentTransaction &&
        other.id == id &&
        other.subscriptionId == subscriptionId &&
        other.membershipId == membershipId &&
        other.amount == amount &&
        other.currency == currency &&
        other.platform == platform &&
        other.productId == productId &&
        other.transactionId == transactionId &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    subscriptionId,
    membershipId,
    amount,
    currency,
    platform,
    productId,
    transactionId,
    status,
    createdAt,
  );
}
