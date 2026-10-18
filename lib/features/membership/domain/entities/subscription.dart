import 'package:meta/meta.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing a user's subscription record.
/// Strictly mapped to users/{userId}/subscriptions/{subscriptionId} in
/// docs/DATABASE.md §16. Written only by Cloud Functions after a payment is
/// reconciled; the active subscription is the source of truth for Premium.
@immutable
class Subscription {
  final String id;
  final String membershipId;

  /// Payment provider that granted the entitlement, e.g. `payos`.
  final String provider;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;

  /// Always `false` for payOS (QR payments are renewed manually).
  final bool autoRenew;
  final bool cancelAtPeriodEnd;

  /// Most recent payment that extended this entitlement.
  final String? lastPaymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.membershipId,
    required this.provider,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = false,
    this.cancelAtPeriodEnd = false,
    this.lastPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this subscription grants entitlement at [now]:
  /// `status == active` and `startDate <= now < endDate`.
  bool isEntitledAt(DateTime now) =>
      status == SubscriptionStatus.active &&
      !startDate.isAfter(now) &&
      endDate.isAfter(now);

  /// [isEntitledAt] evaluated against the device clock.
  bool get isActive => isEntitledAt(DateTime.now());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        other.id == id &&
        other.membershipId == membershipId &&
        other.provider == provider &&
        other.status == status &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.autoRenew == autoRenew &&
        other.cancelAtPeriodEnd == cancelAtPeriodEnd &&
        other.lastPaymentId == lastPaymentId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    membershipId,
    provider,
    status,
    startDate,
    endDate,
    autoRenew,
    cancelAtPeriodEnd,
    lastPaymentId,
    createdAt,
    updatedAt,
  );
}
