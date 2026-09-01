import 'package:flutter/foundation.dart';

/// Pure domain entity representing a household group.
/// Strictly mapped to households/{householdId} in docs/DATABASE.md
@immutable
class Household {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members; // Array of userIds
  final DateTime createdAt;
  final DateTime updatedAt;

  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isOwner(String userId) => ownerId == userId;
  bool isMember(String userId) => members.contains(userId);

  Household copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Household &&
        other.id == id &&
        other.name == name &&
        other.ownerId == ownerId &&
        listEquals(other.members, members) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ownerId,
    Object.hashAll(members),
    createdAt,
    updatedAt,
  );
}
