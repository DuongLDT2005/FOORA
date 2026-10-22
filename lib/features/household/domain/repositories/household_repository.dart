import '../entities/household.dart';
import '../entities/household_invitation.dart';
import '../entities/household_invitation_info.dart';
import '../entities/household_member.dart';

/// Pure domain repository interface for household operations.
abstract class HouseholdRepository {
  /// Real-time stream of a specific household document.
  Stream<Household?> watchHousehold(String householdId);

  /// Real-time stream of all households the user belongs to.
  Stream<List<Household>> watchUserHouseholds(String userId);

  /// Retrieves the list of member public profiles for a household.
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId);

  /// Updates the household name (Owner only).
  Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  });

  /// Generates a new invitation for the household (Owner only).
  Future<HouseholdInvitation> generateInvitation({
    required String householdId,
    int expiresInDays = 7,
  });

  /// Retrieves the currently active invitation for a household (Owner only).
  Future<HouseholdInvitation?> getActiveInvitation(String householdId);

  /// Revokes an active invitation (Owner only).
  Future<void> revokeInvitation({
    required String householdId,
    required String invitationId,
  });

  /// Retrieves preview info for an invitation code before joining.
  Future<HouseholdInvitationInfo> getInvitationInfo(String code);

  /// Joins a household using a valid invitation code.
  Future<void> joinHousehold(String code);

  /// Removes a member from the household (Owner only).
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  });

  /// Voluntarily leaves a household (Member only).
  Future<void> leaveHousehold(String householdId);

  /// Switches active household for the current user.
  Future<void> switchHousehold(String householdId);
}
