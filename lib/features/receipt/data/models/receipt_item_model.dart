import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/receipt_item.dart';

class ReceiptItemModel extends ReceiptItem {
  const ReceiptItemModel({
    required super.id,
    required super.rawName,
    required super.normalizedName,
    super.foodId,
    required super.quantity,
    required super.unit,
    super.confidence,
  });

  factory ReceiptItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ReceiptItemModel.fromJson(data, id: doc.id);
  }

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ReceiptItemModel(
      id: id ?? json['id'] as String? ?? json['receiptItemId'] as String? ?? '',
      rawName: json['rawName'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      foodId: json['foodId'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rawName': rawName,
      'normalizedName': normalizedName,
      if (foodId != null) 'foodId': foodId,
      'quantity': quantity,
      'unit': unit,
      if (confidence != null) 'confidence': confidence,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawName': rawName,
      'normalizedName': normalizedName,
      if (foodId != null) 'foodId': foodId,
      'quantity': quantity,
      'unit': unit,
      if (confidence != null) 'confidence': confidence,
    };
  }
}
