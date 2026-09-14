import 'package:flutter/foundation.dart';
import 'package:foora/core/constants/app_enums.dart';

/// Pure domain entity representing an authenticated user account.
@immutable
class User {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String membershipId; // Foreign key to memberships/{membershipId}, e.g. 'free', 'premium'
  final String? activeHouseholdId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.role = UserRole.member,
    this.membershipId = 'free',
    this.activeHouseholdId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isPremium => membershipId == 'premium';

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    UserRole? role,
    String? membershipId,
    String? activeHouseholdId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      membershipId: membershipId ?? this.membershipId,
      activeHouseholdId: activeHouseholdId ?? this.activeHouseholdId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.fullName == fullName &&
        other.email == email &&
        other.role == role &&
        other.membershipId == membershipId &&
        other.activeHouseholdId == activeHouseholdId &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    email,
    role,
    membershipId,
    activeHouseholdId,
    isActive,
    createdAt,
    updatedAt,
  );
}
