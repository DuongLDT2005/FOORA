import '../entities/household_invitation.dart';
import '../repositories/household_repository.dart';

class GetActiveHouseholdInvitationUseCase {
  final HouseholdRepository _repository;

  const GetActiveHouseholdInvitationUseCase(this._repository);

  Future<HouseholdInvitation?> call(String householdId) {
    return _repository.getActiveInvitation(householdId);
  }
}
