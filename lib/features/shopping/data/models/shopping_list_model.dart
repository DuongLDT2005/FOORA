import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shopping_list.dart';

class ShoppingListModel extends ShoppingList {
  const ShoppingListModel({
    required super.id,
    required super.householdId,
    required super.name,
    super.note,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShoppingListModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? householdId,
  }) {
    final data = doc.data() ?? {};
    return ShoppingListModel.fromJson(
      data,
      id: doc.id,
      householdId: householdId,
    );
  }

  factory ShoppingListModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
    String? householdId,
  }) {
    return ShoppingListModel(
      id: id ?? json['id'] as String? ?? '',
      householdId: householdId ?? json['householdId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      note: json['note'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ShoppingList toEntity() => this;

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
