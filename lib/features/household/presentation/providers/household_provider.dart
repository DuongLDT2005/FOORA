import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/household_remote_datasource.dart';
import '../../data/repositories/household_repository_impl.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_invitation.dart';
import '../../domain/entities/household_invitation_info.dart';
import '../../domain/entities/household_member.dart';
import '../../domain/repositories/household_repository.dart';
import '../../domain/usecases/generate_household_invitation.dart';
import '../../domain/usecases/get_active_household_invitation.dart';
import '../../domain/usecases/get_current_household.dart';
import '../../domain/usecases/get_household_invitation_info.dart';
import '../../domain/usecases/get_household_members.dart';
import '../../domain/usecases/get_user_households.dart';
import '../../domain/usecases/join_household.dart';
import '../../domain/usecases/leave_household.dart';
import '../../domain/usecases/remove_member.dart';
import '../../domain/usecases/revoke_household_invitation.dart';
import '../../domain/usecases/switch_household.dart';
import '../../domain/usecases/update_household_name.dart';
import '../../domain/usecases/validate_invite_code.dart';

// --- Data & Domain Providers ---

final householdRemoteDataSourceProvider = Provider<HouseholdRemoteDataSource>((
  ref,
) {
  return HouseholdRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
  );
});

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepositoryImpl(
    remoteDataSource: ref.watch(householdRemoteDataSourceProvider),
  );
});

final watchCurrentHouseholdUseCaseProvider =
    Provider<WatchCurrentHouseholdUseCase>((ref) {
      return WatchCurrentHouseholdUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final watchUserHouseholdsUseCaseProvider = Provider<WatchUserHouseholdsUseCase>(
  (ref) {
    return WatchUserHouseholdsUseCase(ref.watch(householdRepositoryProvider));
  },
);

final getHouseholdMembersUseCaseProvider = Provider<GetHouseholdMembersUseCase>(
  (ref) {
    return GetHouseholdMembersUseCase(ref.watch(householdRepositoryProvider));
  },
);

final updateHouseholdNameUseCaseProvider = Provider<UpdateHouseholdNameUseCase>(
  (ref) {
    return UpdateHouseholdNameUseCase(ref.watch(householdRepositoryProvider));
  },
);

final generateHouseholdInvitationUseCaseProvider =
    Provider<GenerateHouseholdInvitationUseCase>((ref) {
      return GenerateHouseholdInvitationUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final getActiveHouseholdInvitationUseCaseProvider =
    Provider<GetActiveHouseholdInvitationUseCase>((ref) {
      return GetActiveHouseholdInvitationUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final revokeHouseholdInvitationUseCaseProvider =
    Provider<RevokeHouseholdInvitationUseCase>((ref) {
      return RevokeHouseholdInvitationUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final getHouseholdInvitationInfoUseCaseProvider =
    Provider<GetHouseholdInvitationInfoUseCase>((ref) {
      return GetHouseholdInvitationInfoUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final joinHouseholdUseCaseProvider = Provider<JoinHouseholdUseCase>((ref) {
  return JoinHouseholdUseCase(ref.watch(householdRepositoryProvider));
});

final removeHouseholdMemberUseCaseProvider =
    Provider<RemoveHouseholdMemberUseCase>((ref) {
      return RemoveHouseholdMemberUseCase(
        ref.watch(householdRepositoryProvider),
      );
    });

final leaveHouseholdUseCaseProvider = Provider<LeaveHouseholdUseCase>((ref) {
  return LeaveHouseholdUseCase(ref.watch(householdRepositoryProvider));
});

final switchHouseholdUseCaseProvider = Provider<SwitchHouseholdUseCase>((ref) {
  return SwitchHouseholdUseCase(ref.watch(householdRepositoryProvider));
});

final validateInviteCodeUseCaseProvider = Provider<ValidateInviteCodeUseCase>(
  (ref) => const ValidateInviteCodeUseCase(),
);

// --- Stream & Future UI Providers ---

/// Real-time stream of the current active household.
final currentHouseholdStreamProvider = StreamProvider<Household?>((ref) {
  final user = ref.watch(currentUserProvider);
  final householdId = user?.activeHouseholdId;
  if (householdId == null || householdId.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(watchCurrentHouseholdUseCaseProvider)(householdId);
});

/// Real-time stream of all households the current user has joined.
final userHouseholdsStreamProvider = StreamProvider<List<Household>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(watchUserHouseholdsUseCaseProvider)(user.id);
});

/// FutureProvider to fetch members of a household.
final householdMembersProvider = FutureProvider.autoDispose
    .family<List<HouseholdMember>, String>((ref, householdId) async {
      if (householdId.isEmpty) return [];
      // Refetch when the live member list changes (someone joined, left or
      // was removed), so profiles never lag behind the household document.
      ref.watch(
        currentHouseholdStreamProvider.select((async) {
          final household = async.valueOrNull;
          return household?.id == householdId
              ? household!.members.join(',')
              : null;
        }),
      );
      return ref.watch(getHouseholdMembersUseCaseProvider)(householdId);
    });

/// FutureProvider to fetch active invitation for a household.
final activeHouseholdInvitationProvider = FutureProvider.autoDispose
    .family<HouseholdInvitation?, String>((ref, householdId) async {
      if (householdId.isEmpty) return null;
      return ref.watch(getActiveHouseholdInvitationUseCaseProvider)(
        householdId,
      );
    });

// --- Controller Provider ---

final householdControllerProvider = Provider<HouseholdController>((ref) {
  return HouseholdController(ref);
});

class HouseholdController {
  final Ref ref;

  HouseholdController(this.ref);

  Future<void> updateName(String householdId, String name) async {
    try {
      await ref.read(updateHouseholdNameUseCaseProvider)(
        householdId: householdId,
        name: name,
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể cập nhật tên gia đình: $e');
    }
  }

  Future<HouseholdInvitation> generateInvitation(String householdId) async {
    try {
      final invitation = await ref.read(
        generateHouseholdInvitationUseCaseProvider,
      )(householdId: householdId);
      ref.invalidate(activeHouseholdInvitationProvider(householdId));
      return invitation;
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể tạo mã lời mời: $e');
    }
  }

  Future<void> revokeInvitation(String householdId, String invitationId) async {
    try {
      await ref.read(revokeHouseholdInvitationUseCaseProvider)(
        householdId: householdId,
        invitationId: invitationId,
      );
      ref.invalidate(activeHouseholdInvitationProvider(householdId));
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể thu hồi mã lời mời: $e');
    }
  }

  Future<HouseholdInvitationInfo> getInvitationInfo(String code) async {
    try {
      return await ref.read(getHouseholdInvitationInfoUseCaseProvider)(code);
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể kiểm tra lời mời: $e');
    }
  }

  Future<void> joinHousehold(String code) async {
    try {
      await ref.read(joinHouseholdUseCaseProvider)(code);
      ref.invalidate(userHouseholdsStreamProvider);
      ref.invalidate(currentHouseholdStreamProvider);
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể gia nhập gia đình: $e');
    }
  }

  Future<void> removeMember(String householdId, String memberUserId) async {
    try {
      await ref.read(removeHouseholdMemberUseCaseProvider)(
        householdId: householdId,
        memberUserId: memberUserId,
      );
      ref.invalidate(householdMembersProvider(householdId));
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể xóa thành viên: $e');
    }
  }

  Future<void> leaveHousehold(String householdId) async {
    try {
      await ref.read(leaveHouseholdUseCaseProvider)(householdId);
      ref.invalidate(userHouseholdsStreamProvider);
      ref.invalidate(currentHouseholdStreamProvider);
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể rời gia đình: $e');
    }
  }

  Future<void> switchHousehold(String householdId) async {
    try {
      await ref.read(switchHouseholdUseCaseProvider)(householdId);
      ref.invalidate(currentHouseholdStreamProvider);
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Không thể chuyển đổi gia đình: $e');
    }
  }
}
