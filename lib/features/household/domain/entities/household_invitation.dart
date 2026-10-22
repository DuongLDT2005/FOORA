import 'package:meta/meta.dart';
import '../../../../core/constants/app_enums.dart';

/// Pure domain entity representing an invitation to a household.
@immutable
class HouseholdInvitation {
  final String id;
  final String code;
  final String householdId;
  final String householdName;
  final DateTime expiresAt;
  final HouseholdInvitationStatus status;

  const HouseholdInvitation({
    required this.id,
    required this.code,
    required this.householdId,
    required this.householdName,
    required this.expiresAt,
    this.status = HouseholdInvitationStatus.active,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HouseholdInvitation &&
        other.id == id &&
        other.code == code &&
        other.householdId == householdId &&
        other.householdName == householdName &&
        other.expiresAt == expiresAt &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(id, code, householdId, householdName, expiresAt, status);
}
