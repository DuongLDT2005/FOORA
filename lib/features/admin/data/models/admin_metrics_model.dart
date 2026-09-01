import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/admin_metrics.dart';

class AdminMetricsModel extends AdminMetrics {
  const AdminMetricsModel({
    required super.totalUsers,
    required super.activePremiumUsers,
    required super.totalReceiptScansThisMonth,
    required super.totalFoodItemsTracked,
    super.monthlyRevenue = 0.0,
    required super.updatedAt,
  });

  factory AdminMetricsModel.fromJson(Map<String, dynamic> json) {
    return AdminMetricsModel(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      activePremiumUsers: (json['activePremiumUsers'] as num?)?.toInt() ?? 0,
      totalReceiptScansThisMonth:
          (json['totalReceiptScansThisMonth'] as num?)?.toInt() ?? 0,
      totalFoodItemsTracked:
          (json['totalFoodItemsTracked'] as num?)?.toInt() ?? 0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0.0,
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'activePremiumUsers': activePremiumUsers,
      'totalReceiptScansThisMonth': totalReceiptScansThisMonth,
      'totalFoodItemsTracked': totalFoodItemsTracked,
      'monthlyRevenue': monthlyRevenue,
      'updatedAt': updatedAt.toIso8601String(),
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
