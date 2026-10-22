import '../../../../core/constants/app_enums.dart';
import '../../domain/entities/household_invitation.dart';

/// Data model for [HouseholdInvitation], parsed from Cloud Functions.
class HouseholdInvitationModel extends HouseholdInvitation {
  const HouseholdInvitationModel({
    required super.id,
    required super.code,
    required super.householdId,
    required super.householdName,
    required super.expiresAt,
    required super.shareUrl,
    super.status = HouseholdInvitationStatus.active,
  });

  factory HouseholdInvitationModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    return HouseholdInvitationModel(
      id: id ?? json['invitationId'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      householdId: json['householdId'] as String? ?? '',
      householdName: json['householdName'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      shareUrl: json['shareUrl'] as String? ?? '',
      status: HouseholdInvitationStatus.fromString(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'householdId': householdId,
      'householdName': householdName,
      'expiresAt': expiresAt.toIso8601String(),
      'shareUrl': shareUrl,
      'status': status.value,
    };
  }
}
