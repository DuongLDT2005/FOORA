import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';

import '../../domain/entities/receipt.dart';

class ReceiptModel extends Receipt {
  const ReceiptModel({
    required super.id,
    required super.householdId,
    super.imageUrl,
    super.status = ReceiptStatus.pending,
    super.ocrText,
    super.processedBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ReceiptModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReceiptModel.fromJson(data, id: doc.id);
  }

  factory ReceiptModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ReceiptModel(
      id: id ?? json['id'] as String? ?? json['receiptId'] as String? ?? '',
      householdId: json['householdId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      status: ReceiptStatus.fromString(json['status'] as String?),
      ocrText: json['ocrText'] as String?,
      processedBy: json['processedBy'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'householdId': householdId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'status': status.value,
      if (ocrText != null) 'ocrText': ocrText,
      if (processedBy != null) 'processedBy': processedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'householdId': householdId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'status': status.value,
      if (ocrText != null) 'ocrText': ocrText,
      if (processedBy != null) 'processedBy': processedBy,
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
