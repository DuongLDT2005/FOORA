import '../entities/household.dart';
import '../repositories/household_repository.dart';

class WatchUserHouseholdsUseCase {
  final HouseholdRepository _repository;

  const WatchUserHouseholdsUseCase(this._repository);

  Stream<List<Household>> call(String userId) {
    return _repository.watchUserHouseholds(userId);
  }
}
