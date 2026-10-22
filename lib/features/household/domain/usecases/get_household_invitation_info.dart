import '../entities/household_invitation_info.dart';
import '../repositories/household_repository.dart';

class GetHouseholdInvitationInfoUseCase {
  final HouseholdRepository _repository;

  const GetHouseholdInvitationInfoUseCase(this._repository);

  Future<HouseholdInvitationInfo> call(String code) {
    return _repository.getInvitationInfo(code);
  }
}
