import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing a user's subscription record.
/// Strictly mapped to users/{userId}/subscriptions/{subscriptionId} in docs/DATABASE.md
@immutable
class Subscription {
  final String id;
  final String membershipId;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final bool cancelAtPeriodEnd;
  final AppPlatform platform;
  final String productId;
  final String? purchaseToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.membershipId,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = true,
    this.cancelAtPeriodEnd = false,
    required this.platform,
    required this.productId,
    this.purchaseToken,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive =>
      status == SubscriptionStatus.active && endDate.isAfter(DateTime.now());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        other.id == id &&
        other.membershipId == membershipId &&
        other.status == status &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.autoRenew == autoRenew &&
        other.cancelAtPeriodEnd == cancelAtPeriodEnd &&
        other.platform == platform &&
        other.productId == productId &&
        other.purchaseToken == purchaseToken &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    membershipId,
    status,
    startDate,
    endDate,
    autoRenew,
    cancelAtPeriodEnd,
    platform,
    productId,
    purchaseToken,
    createdAt,
    updatedAt,
  );
}
