import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_enums.dart';

/// Pure domain entity representing a storage location (e.g. Fridge, Freezer).
/// Strictly mapped to storage_locations/{locationId} in docs/DATABASE.md
@immutable
class StorageLocation {
  final String id; // 'fridge' | 'freezer'
  final String name;
  final StorageLocationCode code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StorageLocation({
    required this.id,
    required this.name,
    required this.code,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageLocation &&
        other.id == id &&
        other.name == name &&
        other.code == code &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, code, isActive, createdAt, updatedAt);
}
