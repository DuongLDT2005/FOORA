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
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}
