import 'package:meta/meta.dart';
import '../../../../core/constants/app_enums.dart';

/// Pure domain entity representing a member within a household.
@immutable
class HouseholdMember {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final HouseholdRole role;
  final bool isCurrentUser;
  // Over the owner's plan seat limit; cannot use the household.
  final bool isLocked;

  const HouseholdMember({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.isCurrentUser = false,
    this.isLocked = false,
  });

  bool get isOwner => role == HouseholdRole.owner;

  String get initials {
    if (fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HouseholdMember &&
        other.id == id &&
        other.fullName == fullName &&
        other.avatarUrl == avatarUrl &&
        other.role == role &&
        other.isCurrentUser == isCurrentUser &&
        other.isLocked == isLocked;
  }

  @override
  int get hashCode =>
      Object.hash(id, fullName, avatarUrl, role, isCurrentUser, isLocked);
}
