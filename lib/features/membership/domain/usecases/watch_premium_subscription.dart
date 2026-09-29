import '../entities/subscription.dart';
import '../repositories/membership_repository.dart';

class WatchPremiumSubscription {
  const WatchPremiumSubscription(this.repository);

  final MembershipRepository repository;

  Stream<Subscription?> call() => repository.watchPremiumSubscription();
}
