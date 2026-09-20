import '../../domain/entities/receipt_item.dart';

class ReceiptItemModel extends ReceiptItem {
  const ReceiptItemModel({
    required super.id,
    required super.rawName,
    required super.name,
    required super.normalizedName,
    super.foodId,
    super.categoryId,
    required super.quantity,
    required super.unit,
    super.storageLocationId,
    required super.estimatedExpirationDate,
    super.confidence,
    super.photoUrl,
    super.matchedExistingItem,
  });

  factory ReceiptItemModel.fromBackendJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    MatchedStockAlert? alert;
    if (json['matchedExistingItem'] != null &&
        json['matchedExistingItem'] is Map<String, dynamic>) {
      final m = json['matchedExistingItem'] as Map<String, dynamic>;
      alert = MatchedStockAlert(
        itemId: m['itemId']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        unit: m['unit']?.toString() ?? '',
        storageLocationName: m['storageLocationName']?.toString() ?? 'Ngăn mát',
        expirationDate: m['expirationDate'] != null
            ? DateTime.tryParse(m['expirationDate'].toString()) ??
                DateTime.now()
            : DateTime.now(),
        daysRemaining: (m['daysRemaining'] as num?)?.toInt() ?? 0,
      );
    }

    final expDate = json['estimatedExpirationDate'] != null
        ? DateTime.tryParse(json['estimatedExpirationDate'].toString()) ??
            DateTime.now().add(const Duration(days: 3))
        : DateTime.now().add(const Duration(days: 3));

    return ReceiptItemModel(
      id: id ?? json['id']?.toString() ?? '',
      rawName: json['rawName']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      normalizedName: json['normalizedName']?.toString() ?? '',
      foodId: json['foodId']?.toString(),
      categoryId: json['categoryId']?.toString() ?? 'vegetables',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit']?.toString() ?? 'quả',
      storageLocationId: json['storageLocationId']?.toString() ?? 'fridge',
      estimatedExpirationDate: expDate,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      photoUrl: json['photoUrl']?.toString(),
      matchedExistingItem: alert,
    );
  }

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel.fromBackendJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawName': rawName,
      'name': name,
      'normalizedName': normalizedName,
      'foodId': foodId,
      'categoryId': categoryId,
      'quantity': quantity,
      'unit': unit,
      'storageLocationId': storageLocationId,
      'estimatedExpirationDate': estimatedExpirationDate.toIso8601String(),
      'confidence': confidence,
      'photoUrl': photoUrl,
    };
  }

  Map<String, dynamic> toInventoryItemJson() {
    return {
      'name': name,
      'foodId': foodId,
      'categoryId': categoryId,
      'quantity': quantity,
      'unit': unit,
      'storageLocationId': storageLocationId,
      'purchaseDate': DateTime.now().toIso8601String(),
      'expirationDate': estimatedExpirationDate.toIso8601String(),
      'photoUrl': photoUrl,
      'source': 'receipt_scan',
    };
  }
}
