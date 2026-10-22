import '../repositories/household_repository.dart';

class LeaveHouseholdUseCase {
  final HouseholdRepository _repository;

  const LeaveHouseholdUseCase(this._repository);

  Future<void> call(String householdId) {
    return _repository.leaveHousehold(householdId);
  }
}
