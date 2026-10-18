import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food.dart';

/// Data model for a catalogue food entry (name, category, default shelf life).
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

  /// Builds a model from a Firestore snapshot.
  factory FoodModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FoodModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map.
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

  /// Serializes to a Firestore map.
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

  /// Serializes to a JSON map.
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
