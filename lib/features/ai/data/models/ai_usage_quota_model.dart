import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/ai_usage_quota.dart';

class AiUsageQuotaModel extends AiUsageQuota {
  const AiUsageQuotaModel({
    required super.period,
    required super.receiptScanUsed,
    required super.updatedAt,
  });

  factory AiUsageQuotaModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AiUsageQuotaModel.fromJson(data);
  }

  factory AiUsageQuotaModel.fromJson(Map<String, dynamic> json) {
    return AiUsageQuotaModel(
      period: json['period'] as String? ?? '',
      receiptScanUsed: (json['receiptScanUsed'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'period': period,
      'receiptScanUsed': receiptScanUsed,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'receiptScanUsed': receiptScanUsed,
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
