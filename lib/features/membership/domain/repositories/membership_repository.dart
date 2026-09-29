import '../entities/membership_plan.dart';
import '../entities/subscription.dart';

abstract class MembershipRepository {
  Future<MembershipPlan> getMembershipPlan(String membershipId);
  Stream<Subscription?> watchPremiumSubscription();
  Future<void> updateAutoRenew(bool enabled);
}
