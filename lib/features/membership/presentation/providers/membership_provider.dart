import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/membership_remote_datasource.dart';
import '../../data/repositories/membership_repository_impl.dart';
import '../../domain/entities/membership_plan.dart';
import '../../domain/repositories/membership_repository.dart';
import '../../domain/usecases/get_membership_plans.dart';

final membershipRemoteDataSourceProvider = Provider<MembershipRemoteDataSource>(
  (ref) {
    return MembershipRemoteDataSourceImpl(
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

final membershipPlanProvider = FutureProvider.family<MembershipPlan, String>((
  ref,
  membershipId,
) {
  return ref.watch(getMembershipPlanUseCaseProvider).call(membershipId);
});
