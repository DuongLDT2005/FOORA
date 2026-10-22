import 'package:meta/meta.dart';

/// Pure domain entity representing invitation preview details shown to a user
/// before they confirm joining a household (FR-04).
@immutable
class HouseholdInvitationInfo {
  final String code;
  final String householdId;
  final String householdName;
  final String ownerName;
  final int memberCount;

  /// Seats allowed by the owner's plan, owner included.
  final int memberLimit;
  final bool alreadyMember;
  final DateTime expiresAt;

  bool get isFull => memberCount >= memberLimit;

  const HouseholdInvitationInfo({
    required this.code,
    required this.householdId,
    required this.householdName,
    required this.ownerName,
    required this.memberCount,
    required this.memberLimit,
    required this.alreadyMember,
    required this.expiresAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HouseholdInvitationInfo &&
        other.code == code &&
        other.householdId == householdId &&
        other.householdName == householdName &&
        other.ownerName == ownerName &&
        other.memberCount == memberCount &&
        other.memberLimit == memberLimit &&
        other.alreadyMember == alreadyMember &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(
    code,
    householdId,
    householdName,
    ownerName,
    memberCount,
    memberLimit,
    alreadyMember,
    expiresAt,
  );
}
