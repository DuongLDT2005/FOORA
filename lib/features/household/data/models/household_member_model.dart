import '../../../../core/constants/app_enums.dart';
import '../../domain/entities/household_member.dart';

/// Data model for [HouseholdMember], parsed from the `getHouseholdMembers` Cloud Function.
class HouseholdMemberModel extends HouseholdMember {
  const HouseholdMemberModel({
    required super.id,
    required super.fullName,
    required super.email,
    super.avatarUrl,
    required super.role,
    super.isCurrentUser = false,
  });

  factory HouseholdMemberModel.fromJson(Map<String, dynamic> json) {
    return HouseholdMemberModel(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: HouseholdRole.fromString(json['role'] as String?),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'isCurrentUser': isCurrentUser,
    };
  }
}
