import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/membership_remote_datasource.dart';
import '../../data/repositories/membership_repository_impl.dart';
import '../../domain/entities/membership_plan.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/membership_repository.dart';
import '../../domain/usecases/get_membership_plans.dart';
import '../../domain/usecases/update_auto_renew.dart';
import '../../domain/usecases/watch_premium_subscription.dart';

final membershipRemoteDataSourceProvider = Provider<MembershipRemoteDataSource>(
  (ref) {
    return MembershipRemoteDataSourceImpl(
      auth: ref.watch(firebaseAuthProvider),
      firestore: ref.watch(firestoreProvider),
      functions: ref.watch(functionsProvider),
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

final updateAutoRenewProvider = Provider<UpdateAutoRenew>((ref) {
  return UpdateAutoRenew(ref.watch(membershipRepositoryProvider));
});

final premiumSubscriptionProvider = StreamProvider<Subscription?>((ref) {
  return ref.watch(watchPremiumSubscriptionProvider).call();
});

final autoRenewUpdateControllerProvider =
    AsyncNotifierProvider<AutoRenewUpdateController, void>(
      AutoRenewUpdateController.new,
    );

class AutoRenewUpdateController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateAutoRenew(bool enabled) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref.read(updateAutoRenewProvider).call(enabled);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
