import '../repositories/household_repository.dart';

class SwitchHouseholdUseCase {
  final HouseholdRepository _repository;

  const SwitchHouseholdUseCase(this._repository);

  Future<void> call(String householdId) {
    return _repository.switchHousehold(householdId);
  }
}
