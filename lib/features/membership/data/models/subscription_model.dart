import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/subscription.dart';

class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.membershipId,
    required super.status,
    required super.startDate,
    required super.endDate,
    super.autoRenew = true,
    super.cancelAtPeriodEnd = false,
    required super.platform,
    required super.productId,
    super.purchaseToken,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SubscriptionModel.fromJson(data, id: doc.id);
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return SubscriptionModel(
      id: id ?? json['id'] as String? ?? '',
      membershipId: json['membershipId'] as String? ?? '',
      status: SubscriptionStatus.fromString(json['status'] as String?),
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      autoRenew: json['autoRenew'] as bool? ?? true,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      platform: AppPlatform.fromString(json['platform'] as String?),
      productId: json['productId'] as String? ?? '',
      purchaseToken: json['purchaseToken'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'membershipId': membershipId,
      'status': status.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'autoRenew': autoRenew,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'platform': platform.value,
      'productId': productId,
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membershipId': membershipId,
      'status': status.value,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'autoRenew': autoRenew,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'platform': platform.value,
      'productId': productId,
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
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
