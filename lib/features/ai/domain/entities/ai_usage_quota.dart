import 'package:flutter/foundation.dart';

/// Pure domain entity representing monthly AI quota usage.
/// Strictly mapped to users/{userId}/ai_usage/current in docs/DATABASE.md
@immutable
class AiUsageQuota {
  final String period; // e.g. '2026-09'
  final int receiptScanUsed;
  final DateTime updatedAt;

  const AiUsageQuota({
    required this.period,
    required this.receiptScanUsed,
    required this.updatedAt,
  });

  AiUsageQuota copyWith({
    String? period,
    int? receiptScanUsed,
    DateTime? updatedAt,
  }) {
    return AiUsageQuota(
      period: period ?? this.period,
      receiptScanUsed: receiptScanUsed ?? this.receiptScanUsed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiUsageQuota &&
        other.period == period &&
        other.receiptScanUsed == receiptScanUsed &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(period, receiptScanUsed, updatedAt);
}
