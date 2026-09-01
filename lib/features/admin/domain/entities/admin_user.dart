import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/auth/domain/entities/user.dart';

/// Domain entity representing a user in the Web Admin user management panel.
class AdminUser extends User {
  final int householdCount;
  final int receiptScanCount;

  const AdminUser({
    required super.id,
    required super.fullName,
    required super.email,
    super.role = UserRole.member,
    super.membershipId = 'free',
    super.activeHouseholdId,
    super.isActive = true,
    this.householdCount = 1,
    this.receiptScanCount = 0,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AdminUser.fromUser(
    User user, {
    int householdCount = 1,
    int receiptScanCount = 0,
  }) {
    return AdminUser(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      membershipId: user.membershipId,
      activeHouseholdId: user.activeHouseholdId,
      isActive: user.isActive,
      householdCount: householdCount,
      receiptScanCount: receiptScanCount,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}
