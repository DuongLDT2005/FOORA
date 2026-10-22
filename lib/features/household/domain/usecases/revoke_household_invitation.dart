import '../repositories/household_repository.dart';

class RevokeHouseholdInvitationUseCase {
  final HouseholdRepository _repository;

  const RevokeHouseholdInvitationUseCase(this._repository);

  Future<void> call({
    required String householdId,
    required String invitationId,
  }) {
    return _repository.revokeInvitation(
      householdId: householdId,
      invitationId: invitationId,
    );
  }
}
