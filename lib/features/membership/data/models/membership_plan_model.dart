import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/membership_plan.dart';

class MembershipPlanModel extends MembershipPlan {
  const MembershipPlanModel({
    required super.id,
    required super.name,
    required super.price,
    super.currency = 'VND',
    super.durationDays,
    super.foodLimit,
    super.receiptScanQuota,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory MembershipPlanModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return MembershipPlanModel.fromJson(data, id: doc.id);
  }

  factory MembershipPlanModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return MembershipPlanModel(
      id: id ?? json['id'] as String? ?? json['membershipId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'VND',
      durationDays: (json['durationDays'] as num?)?.toInt(),
      foodLimit: (json['foodLimit'] as num?)?.toInt(),
      receiptScanQuota: (json['receiptScanQuota'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'currency': currency,
      'durationDays': durationDays,
      'foodLimit': foodLimit,
      'receiptScanQuota': receiptScanQuota,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'durationDays': durationDays,
      'foodLimit': foodLimit,
      'receiptScanQuota': receiptScanQuota,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
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
