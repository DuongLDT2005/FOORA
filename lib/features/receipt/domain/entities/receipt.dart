import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing a scanned receipt document.
/// Strictly mapped to users/{userId}/receipts/{receiptId} in docs/DATABASE.md
@immutable
class Receipt {
  final String id;
  final String householdId;
  final String? imageUrl;
  final ReceiptStatus status;
  final String? ocrText;
  final String? processedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Receipt({
    required this.id,
    required this.householdId,
    this.imageUrl,
    this.status = ReceiptStatus.pending,
    this.ocrText,
    this.processedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == ReceiptStatus.completed;
  bool get isProcessing => status == ReceiptStatus.processing;
  bool get isFailed => status == ReceiptStatus.failed;

  Receipt copyWith({
    String? id,
    String? householdId,
    String? imageUrl,
    ReceiptStatus? status,
    String? ocrText,
    String? processedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      ocrText: ocrText ?? this.ocrText,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt &&
        other.id == id &&
        other.householdId == householdId &&
        other.imageUrl == imageUrl &&
        other.status == status &&
        other.ocrText == ocrText &&
        other.processedBy == processedBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    householdId,
    imageUrl,
    status,
    ocrText,
    processedBy,
    createdAt,
    updatedAt,
  );
}
