import '../repositories/household_repository.dart';

class RemoveHouseholdMemberUseCase {
  final HouseholdRepository _repository;

  const RemoveHouseholdMemberUseCase(this._repository);

  Future<void> call({
    required String householdId,
    required String memberUserId,
  }) {
    return _repository.removeMember(
      householdId: householdId,
      memberUserId: memberUserId,
    );
  }
}
