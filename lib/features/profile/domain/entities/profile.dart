import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/auth/domain/entities/user.dart';

/// Profile entity represents the user's profile view and update data.
/// Inherits directly from [User] to preserve single-source of truth.
class Profile extends User {
  const Profile({
    required super.id,
    required super.fullName,
    required super.email,
    super.role = UserRole.member,
    super.membershipId = 'free',
    super.activeHouseholdId,
    super.avatarUrl,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  });

  factory Profile.fromUser(User user) {
    return Profile(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      membershipId: user.membershipId,
      activeHouseholdId: user.activeHouseholdId,
      avatarUrl: user.avatarUrl,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Returns 1-2 letters initial for avatar fallback (e.g. 'Duong Le' -> 'DL')
  String get initials {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }
}
