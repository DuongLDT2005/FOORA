import '../entities/household.dart';
import '../repositories/household_repository.dart';

class WatchCurrentHouseholdUseCase {
  final HouseholdRepository _repository;

  const WatchCurrentHouseholdUseCase(this._repository);

  Stream<Household?> call(String householdId) {
    return _repository.watchHousehold(householdId);
  }
}
