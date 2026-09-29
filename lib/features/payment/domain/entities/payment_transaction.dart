import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

@immutable
class PaymentTransaction {
  final String id;
  final String membershipId;
  final double amount;
  final String currency;
  final String provider;
  final String providerRequestId;
  final String referenceNumber;
  final String providerTransactionId;
  final String subscriptionId;
  final String qrCode;
  final String virtualAccountNumber;
  final String description;
  final PaymentStatus status;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String reviewReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Legacy IAP adapter fields retained while existing records are migrated.
  final AppPlatform platform;
  final String productId;
  final String transactionId;

  const PaymentTransaction({
    required this.id,
    required this.membershipId,
    required this.amount,
    this.currency = 'VND',
    this.provider = 'cas',
    this.providerRequestId = '',
    this.referenceNumber = '',
    this.providerTransactionId = '',
    this.subscriptionId = '',
    this.qrCode = '',
    this.virtualAccountNumber = '',
    this.description = '',
    this.status = PaymentStatus.pending,
    this.expiresAt,
    this.paidAt,
    this.cancelledAt,
    this.reviewReason = '',
    required this.createdAt,
    DateTime? updatedAt,
    this.platform = AppPlatform.android,
    this.productId = '',
    this.transactionId = '',
  }) : updatedAt = updatedAt ?? createdAt;

  bool get isTerminal => status != PaymentStatus.pending;
  bool get isCompleted => status == PaymentStatus.completed;
}
