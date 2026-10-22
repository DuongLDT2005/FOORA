import '../repositories/household_repository.dart';

class UpdateHouseholdNameUseCase {
  final HouseholdRepository _repository;

  const UpdateHouseholdNameUseCase(this._repository);

  Future<void> call({required String householdId, required String name}) {
    return _repository.updateHouseholdName(
      householdId: householdId,
      name: name,
    );
  }
}
