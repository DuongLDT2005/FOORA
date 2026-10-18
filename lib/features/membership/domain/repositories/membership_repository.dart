import '../entities/membership_plan.dart';
import '../entities/subscription.dart';

abstract class MembershipRepository {
  Future<MembershipPlan> getMembershipPlan(String membershipId);

  /// Streams the current user's active subscription (the source of truth for
  /// Premium entitlement), or `null` when the user has none.
  Stream<Subscription?> watchPremiumSubscription();
}
