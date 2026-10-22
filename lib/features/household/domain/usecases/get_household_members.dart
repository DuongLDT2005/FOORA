import '../entities/household_member.dart';
import '../repositories/household_repository.dart';

class GetHouseholdMembersUseCase {
  final HouseholdRepository _repository;

  const GetHouseholdMembersUseCase(this._repository);

  Future<List<HouseholdMember>> call(String householdId) {
    return _repository.getHouseholdMembers(householdId);
  }
}
