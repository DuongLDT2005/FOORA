import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Pure domain entity representing a household group.
/// Strictly mapped to households/{householdId} in docs/DATABASE.md
@immutable
class Household {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members; // Array of userIds
  final int activeItemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    this.activeItemCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether [userId] created / owns this household.
  bool isOwner(String userId) => ownerId == userId;

  /// Whether [userId] belongs to this household.
  bool isMember(String userId) => members.contains(userId);

  Household copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? members,
    int? activeItemCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      activeItemCount: activeItemCount ?? this.activeItemCount,
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
        const ListEquality<dynamic>().equals(other.members, members) &&
        other.activeItemCount == activeItemCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ownerId,
    Object.hashAll(members),
    activeItemCount,
    createdAt,
    updatedAt,
  );
}
