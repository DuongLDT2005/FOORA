import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/admin/domain/entities/admin_user.dart';
import 'package:foora/features/auth/data/models/user_model.dart';

class AdminUserModel extends AdminUser {
  const AdminUserModel({
    required super.id,
    required super.fullName,
    required super.email,
    super.role = UserRole.member,
    super.membershipId = 'free',
    super.activeHouseholdId,
    super.isActive = true,
    super.householdCount = 1,
    super.receiptScanCount = 0,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AdminUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int householdCount = 1,
    int receiptScanCount = 0,
  }) {
    final userModel = UserModel.fromFirestore(doc);
    return AdminUserModel(
      id: userModel.id,
      fullName: userModel.fullName,
      email: userModel.email,
      role: userModel.role,
      membershipId: userModel.membershipId,
      activeHouseholdId: userModel.activeHouseholdId,
      isActive: userModel.isActive,
      householdCount: householdCount,
      receiptScanCount: receiptScanCount,
      createdAt: userModel.createdAt,
      updatedAt: userModel.updatedAt,
    );
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final userModel = UserModel.fromJson(json, id: id);
    return AdminUserModel(
      id: userModel.id,
      fullName: userModel.fullName,
      email: userModel.email,
      role: userModel.role,
      membershipId: userModel.membershipId,
      activeHouseholdId: userModel.activeHouseholdId,
      isActive: userModel.isActive,
      householdCount: (json['householdCount'] as num?)?.toInt() ?? 1,
      receiptScanCount: (json['receiptScanCount'] as num?)?.toInt() ?? 0,
      createdAt: userModel.createdAt,
      updatedAt: userModel.updatedAt,
    );
  }
}
