import '../repositories/household_repository.dart';

class JoinHouseholdUseCase {
  final HouseholdRepository _repository;

  const JoinHouseholdUseCase(this._repository);

  Future<void> call(String code) {
    return _repository.joinHousehold(code);
  }
}
