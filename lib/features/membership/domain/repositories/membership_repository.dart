import '../entities/membership_plan.dart';

abstract class MembershipRepository {
  Future<MembershipPlan> getMembershipPlan(String membershipId);
}
