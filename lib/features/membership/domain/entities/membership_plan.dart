import 'package:flutter/foundation.dart';

/// Pure domain entity representing a membership plan tier (Free / Premium).
/// Strictly mapped to memberships/{membershipId} in docs/DATABASE.md
@immutable
class MembershipPlan {
  final String id; // 'free' | 'premium'
  final String name;
  final double price;
  final String currency; // 'VND'
  final int? durationDays; // null = lifetime/unlimited, 30 = monthly
  final int? foodLimit; // 50 for Free, null = unlimited
  final int? receiptScanQuota; // 5/month for Free, null = unlimited
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MembershipPlan({
    required this.id,
    required this.name,
    required this.price,
    this.currency = 'VND',
    this.durationDays,
    this.foodLimit,
    this.receiptScanQuota,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFree => price == 0;
  bool get isUnlimitedScans => receiptScanQuota == null;
  bool get isUnlimitedFood => foodLimit == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MembershipPlan &&
        other.id == id &&
        other.name == name &&
        other.price == price &&
        other.currency == currency &&
        other.durationDays == durationDays &&
        other.foodLimit == foodLimit &&
        other.receiptScanQuota == receiptScanQuota &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    price,
    currency,
    durationDays,
    foodLimit,
    receiptScanQuota,
    isActive,
    createdAt,
    updatedAt,
  );
}
