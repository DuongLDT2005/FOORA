import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food.dart';

class FoodModel extends Food {
  const FoodModel({
    required super.id,
    required super.name,
    required super.normalizedName,
    required super.categoryId,
    required super.defaultUnit,
    super.aliases = const [],
    super.photoUrl = '',
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory FoodModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FoodModel.fromJson(data, id: doc.id);
  }

  factory FoodModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return FoodModel(
      id: id ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      defaultUnit: json['defaultUnit'] as String? ?? '',
      aliases:
          (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      photoUrl: json['photoUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'defaultUnit': defaultUnit,
      'aliases': aliases,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalizedName': normalizedName,
      'categoryId': categoryId,
      'defaultUnit': defaultUnit,
      'aliases': aliases,
      'photoUrl': photoUrl,
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
