import '../../domain/entities/household_invitation_info.dart';

/// Data model for [HouseholdInvitationInfo], parsed from `getHouseholdInvitationInfo` Cloud Function.
class HouseholdInvitationInfoModel extends HouseholdInvitationInfo {
  const HouseholdInvitationInfoModel({
    required super.code,
    required super.householdId,
    required super.householdName,
    required super.ownerName,
    required super.memberCount,
    required super.memberLimit,
    required super.alreadyMember,
    required super.expiresAt,
  });

  factory HouseholdInvitationInfoModel.fromJson(Map<String, dynamic> json) {
    return HouseholdInvitationInfoModel(
      code: json['code'] as String? ?? '',
      householdId: json['householdId'] as String? ?? '',
      householdName: json['householdName'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? 'Chủ gia đình',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      // Older backends omit the limit; never treat the household as full then.
      memberLimit: (json['memberLimit'] as num?)?.toInt() ?? 1 << 30,
      alreadyMember: json['alreadyMember'] as bool? ?? false,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'householdId': householdId,
      'householdName': householdName,
      'ownerName': ownerName,
      'memberCount': memberCount,
      'memberLimit': memberLimit,
      'alreadyMember': alreadyMember,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
