import 'package:flutter/foundation.dart';

/// Pure domain entity representing a standard food item in global catalog.
/// Strictly mapped to foods/{foodId} in docs/DATABASE.md
@immutable
class Food {
  final String id;
  final String name;
  final String normalizedName;
  final String categoryId;
  final String defaultUnit;
  final List<String> aliases;
  final String photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Food({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.categoryId,
    required this.defaultUnit,
    this.aliases = const [],
    this.photoUrl = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Food &&
        other.id == id &&
        other.name == name &&
        other.normalizedName == normalizedName &&
        other.categoryId == categoryId &&
        other.defaultUnit == defaultUnit &&
        listEquals(other.aliases, aliases) &&
        other.photoUrl == photoUrl &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    normalizedName,
    categoryId,
    defaultUnit,
    Object.hashAll(aliases),
    photoUrl,
    isActive,
    createdAt,
    updatedAt,
  );
}
