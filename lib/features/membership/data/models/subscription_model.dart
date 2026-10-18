import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/subscription.dart';

/// Data model for `users/{userId}/subscriptions/{id}`.
class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.membershipId,
    required super.provider,
    required super.status,
    required super.startDate,
    required super.endDate,
    super.autoRenew = false,
    super.cancelAtPeriodEnd = false,
    super.lastPaymentId,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a model from a Firestore snapshot.
  factory SubscriptionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SubscriptionModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map.
  factory SubscriptionModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return SubscriptionModel(
      id: id ?? json['id'] as String? ?? '',
      membershipId: json['membershipId'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      status: SubscriptionStatus.fromString(json['status'] as String?),
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      autoRenew: json['autoRenew'] as bool? ?? false,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      lastPaymentId: json['lastPaymentId'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Serializes to a Firestore map (dates as [Timestamp]).
  Map<String, dynamic> toFirestore() {
    return {
      'membershipId': membershipId,
      'provider': provider,
      'status': status.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'autoRenew': autoRenew,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (lastPaymentId != null) 'lastPaymentId': lastPaymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Serializes to a JSON map (dates as ISO-8601 strings).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membershipId': membershipId,
      'provider': provider,
      'status': status.value,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'autoRenew': autoRenew,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (lastPaymentId != null) 'lastPaymentId': lastPaymentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Accepts a Timestamp, ISO string or epoch millis; falls back to now.
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
