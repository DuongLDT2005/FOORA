import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/membership_remote_datasource.dart';
import '../../data/repositories/membership_repository_impl.dart';
import '../../domain/entities/membership_plan.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/membership_repository.dart';
import '../../domain/usecases/get_membership_plans.dart';
import '../../domain/usecases/watch_premium_subscription.dart';

// --- Data & Domain Providers ---
final membershipRemoteDataSourceProvider = Provider<MembershipRemoteDataSource>(
  (ref) {
    return MembershipRemoteDataSourceImpl(
      auth: ref.watch(firebaseAuthProvider),
      firestore: ref.watch(firestoreProvider),
    );
  },
);

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepositoryImpl(
    remoteDataSource: ref.watch(membershipRemoteDataSourceProvider),
  );
});

final getMembershipPlanUseCaseProvider = Provider<GetMembershipPlanUseCase>((
  ref,
) {
  return GetMembershipPlanUseCase(ref.watch(membershipRepositoryProvider));
});

/// Loads a membership plan by id (cached per id thanks to `.family`).
final membershipPlanProvider = FutureProvider.family<MembershipPlan, String>((
  ref,
  membershipId,
) {
  return ref.watch(getMembershipPlanUseCaseProvider).call(membershipId);
});

final watchPremiumSubscriptionProvider = Provider<WatchPremiumSubscription>((
  ref,
) {
  return WatchPremiumSubscription(ref.watch(membershipRepositoryProvider));
});

/// Real-time Premium subscription of the current user (null = Free plan).
final premiumSubscriptionProvider = StreamProvider<Subscription?>((ref) {
  // Re-subscribe whenever the signed-in user changes.
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(watchPremiumSubscriptionProvider).call();
});
