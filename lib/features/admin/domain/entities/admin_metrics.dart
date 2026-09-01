import 'package:flutter/foundation.dart';

/// Pure domain entity representing system dashboard metrics for Web Admin.
@immutable
class AdminMetrics {
  final int totalUsers;
  final int activePremiumUsers;
  final int totalReceiptScansThisMonth;
  final int totalFoodItemsTracked;
  final double monthlyRevenue;
  final DateTime updatedAt;

  const AdminMetrics({
    required this.totalUsers,
    required this.activePremiumUsers,
    required this.totalReceiptScansThisMonth,
    required this.totalFoodItemsTracked,
    this.monthlyRevenue = 0.0,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminMetrics &&
        other.totalUsers == totalUsers &&
        other.activePremiumUsers == activePremiumUsers &&
        other.totalReceiptScansThisMonth == totalReceiptScansThisMonth &&
        other.totalFoodItemsTracked == totalFoodItemsTracked &&
        other.monthlyRevenue == monthlyRevenue &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    totalUsers,
    activePremiumUsers,
    totalReceiptScansThisMonth,
    totalFoodItemsTracked,
    monthlyRevenue,
    updatedAt,
  );
}
