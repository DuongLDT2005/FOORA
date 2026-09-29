import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/auth/data/models/user_model.dart';
import 'package:foora/features/profile/domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
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

  factory ProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final userModel = UserModel.fromFirestore(doc);
    return ProfileModel.fromUserModel(userModel);
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final userModel = UserModel.fromJson(json, id: id);
    return ProfileModel.fromUserModel(userModel);
  }

  factory ProfileModel.fromUserModel(UserModel userModel) {
    return ProfileModel(
      id: userModel.id,
      fullName: userModel.fullName,
      email: userModel.email,
      role: userModel.role,
      membershipId: userModel.membershipId,
      activeHouseholdId: userModel.activeHouseholdId,
      avatarUrl: userModel.avatarUrl,
      isActive: userModel.isActive,
      createdAt: userModel.createdAt,
      updatedAt: userModel.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return UserModel.fromEntity(this).toFirestore();
  }

  Map<String, dynamic> toJson() {
    return UserModel.fromEntity(this).toJson();
  }
}
