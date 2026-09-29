import '../entities/membership_plan.dart';
import '../repositories/membership_repository.dart';

class GetMembershipPlanUseCase {
  final MembershipRepository repository;

  GetMembershipPlanUseCase(this.repository);

  Future<MembershipPlan> call(String membershipId) {
    return repository.getMembershipPlan(membershipId);
  }
}
