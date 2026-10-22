import '../entities/household_invitation.dart';
import '../repositories/household_repository.dart';

class GenerateHouseholdInvitationUseCase {
  final HouseholdRepository _repository;

  const GenerateHouseholdInvitationUseCase(this._repository);

  Future<HouseholdInvitation> call({
    required String householdId,
    int expiresInDays = 7,
  }) {
    return _repository.generateInvitation(
      householdId: householdId,
      expiresInDays: expiresInDays,
    );
  }
}
