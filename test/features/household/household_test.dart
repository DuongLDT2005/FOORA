import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/household/domain/entities/household.dart';
import 'package:foora/features/household/domain/entities/household_invitation.dart';
import 'package:foora/features/household/domain/entities/household_invitation_info.dart';
import 'package:foora/features/household/domain/entities/household_member.dart';
import 'package:foora/features/household/domain/repositories/household_repository.dart';
import 'package:foora/features/household/domain/usecases/generate_household_invitation.dart';
import 'package:foora/features/household/domain/usecases/get_current_household.dart';
import 'package:foora/features/household/domain/usecases/get_user_households.dart';
import 'package:foora/features/household/domain/usecases/join_household.dart';
import 'package:foora/features/household/domain/usecases/leave_household.dart';
import 'package:foora/features/household/domain/usecases/remove_member.dart';
import 'package:foora/features/household/domain/usecases/revoke_household_invitation.dart';
import 'package:foora/features/household/domain/usecases/switch_household.dart';
import 'package:foora/features/household/domain/usecases/update_household_name.dart';

class FakeHouseholdRepository implements HouseholdRepository {
  final Map<String, Household> households = {};
  final List<HouseholdMember> members = [];
  HouseholdInvitation? activeInvitation;
  HouseholdInvitationInfo? invitationInfo;
  String? switchedHouseholdId;
  String? leftHouseholdId;
  String? removedMemberId;
  String? updatedName;

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return Stream.value(households[householdId]);
  }

  @override
  Stream<List<Household>> watchUserHouseholds(String userId) {
    return Stream.value(
      households.values.where((h) => h.members.contains(userId)).toList(),
    );
  }

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    return members;
  }

  @override
  Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  }) async {
    updatedName = name;
  }

  @override
  Future<HouseholdInvitation> generateInvitation({
    required String householdId,
    int expiresInDays = 7,
  }) async {
    final inv = HouseholdInvitation(
      id: 'inv-123',
      code: 'FOORA-TEST',
      householdId: householdId,
      householdName: 'Gia đình Test',
      expiresAt: DateTime.now().add(Duration(days: expiresInDays)),
      shareUrl: 'https://foora.app/household/join?code=FOORA-TEST',
    );
    activeInvitation = inv;
    return inv;
  }

  @override
  Future<HouseholdInvitation?> getActiveInvitation(String householdId) async {
    return activeInvitation;
  }

  @override
  Future<void> revokeInvitation({
    required String householdId,
    required String invitationId,
  }) async {
    activeInvitation = null;
  }

  @override
  Future<HouseholdInvitationInfo> getInvitationInfo(String code) async {
    if (invitationInfo != null) return invitationInfo!;
    return HouseholdInvitationInfo(
      code: code,
      householdId: 'h-1',
      householdName: 'Gia đình Test',
      ownerName: 'Nguyễn Văn A',
      memberCount: 2,
      alreadyMember: false,
      expiresAt: DateTime.now().add(const Duration(days: 5)),
    );
  }

  @override
  Future<void> joinHousehold(String code) async {}

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  }) async {
    removedMemberId = memberUserId;
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    leftHouseholdId = householdId;
  }

  @override
  Future<void> switchHousehold(String householdId) async {
    switchedHouseholdId = householdId;
  }
}

void main() {
  group('Household Domain Entities Tests', () {
    test('Household entity isOwner and isMember work correctly', () {
      final now = DateTime.now();
      final household = Household(
        id: 'h-100',
        name: 'Gia đình FOORA',
        ownerId: 'owner-1',
        members: ['owner-1', 'member-2'],
        activeItemCount: 5,
        createdAt: now,
        updatedAt: now,
      );

      expect(household.isOwner('owner-1'), isTrue);
      expect(household.isOwner('member-2'), isFalse);
      expect(household.isMember('member-2'), isTrue);
      expect(household.isMember('stranger-3'), isFalse);
    });

    test('HouseholdMember entity computes initials and role checks', () {
      const owner = HouseholdMember(
        id: 'u-1',
        fullName: 'Nguyễn Văn An',
        email: 'an@gmail.com',
        role: HouseholdRole.owner,
        isCurrentUser: true,
      );

      const member = HouseholdMember(
        id: 'u-2',
        fullName: 'Bình',
        email: 'binh@gmail.com',
        role: HouseholdRole.member,
      );

      expect(owner.isOwner, isTrue);
      expect(owner.initials, 'NA');
      expect(member.isOwner, isFalse);
      expect(member.initials, 'B');
    });

    test('HouseholdInvitation isExpired checks correctly', () {
      final expiredInv = HouseholdInvitation(
        id: 'inv-1',
        code: 'EXP-123',
        householdId: 'h-1',
        householdName: 'Test',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        shareUrl: 'https://foora.app/household/join?code=EXP-123',
      );

      final validInv = HouseholdInvitation(
        id: 'inv-2',
        code: 'VAL-123',
        householdId: 'h-1',
        householdName: 'Test',
        expiresAt: DateTime.now().add(const Duration(days: 2)),
        shareUrl: 'https://foora.app/household/join?code=VAL-123',
      );

      expect(expiredInv.isExpired, isTrue);
      expect(validInv.isExpired, isFalse);
    });
  });

  group('Household Domain UseCases Tests', () {
    late FakeHouseholdRepository repository;

    setUp(() {
      repository = FakeHouseholdRepository();
    });

    test('WatchCurrentHouseholdUseCase emits current household', () async {
      final now = DateTime.now();
      repository.households['h-1'] = Household(
        id: 'h-1',
        name: 'Nhà của tôi',
        ownerId: 'u-1',
        members: ['u-1'],
        createdAt: now,
        updatedAt: now,
      );

      final useCase = WatchCurrentHouseholdUseCase(repository);
      final emitted = await useCase('h-1').first;

      expect(emitted, isNotNull);
      expect(emitted?.name, 'Nhà của tôi');
    });

    test('WatchUserHouseholdsUseCase emits list of joined households', () async {
      final now = DateTime.now();
      repository.households['h-1'] = Household(
        id: 'h-1',
        name: 'Nhà A',
        ownerId: 'u-1',
        members: ['u-1'],
        createdAt: now,
        updatedAt: now,
      );
      repository.households['h-2'] = Household(
        id: 'h-2',
        name: 'Nhà B',
        ownerId: 'u-2',
        members: ['u-1', 'u-2'],
        createdAt: now,
        updatedAt: now,
      );

      final useCase = WatchUserHouseholdsUseCase(repository);
      final list = await useCase('u-1').first;

      expect(list.length, 2);
    });

    test('UpdateHouseholdNameUseCase updates name via repository', () async {
      final useCase = UpdateHouseholdNameUseCase(repository);
      await useCase(householdId: 'h-1', name: 'Tên mới');

      expect(repository.updatedName, 'Tên mới');
    });

    test('GenerateHouseholdInvitationUseCase generates invitation', () async {
      final useCase = GenerateHouseholdInvitationUseCase(repository);
      final inv = await useCase(householdId: 'h-1');

      expect(inv.code, 'FOORA-TEST');
      expect(repository.activeInvitation?.code, 'FOORA-TEST');
    });

    test('RevokeHouseholdInvitationUseCase clears active invitation', () async {
      repository.activeInvitation = HouseholdInvitation(
        id: 'inv-1',
        code: 'FOORA-TEST',
        householdId: 'h-1',
        householdName: 'Test',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        shareUrl: 'https://foora.app/household/join?code=FOORA-TEST',
      );

      final useCase = RevokeHouseholdInvitationUseCase(repository);
      await useCase(householdId: 'h-1', invitationId: 'inv-1');

      expect(repository.activeInvitation, isNull);
    });

    test('JoinHouseholdUseCase delegates to repository', () async {
      final useCase = JoinHouseholdUseCase(repository);
      await expectLater(useCase('FOORA-TEST'), completes);
    });

    test('RemoveHouseholdMemberUseCase delegates to repository', () async {
      final useCase = RemoveHouseholdMemberUseCase(repository);
      await useCase(householdId: 'h-1', memberUserId: 'u-99');

      expect(repository.removedMemberId, 'u-99');
    });

    test('LeaveHouseholdUseCase delegates to repository', () async {
      final useCase = LeaveHouseholdUseCase(repository);
      await useCase('h-1');

      expect(repository.leftHouseholdId, 'h-1');
    });

    test('SwitchHouseholdUseCase delegates to repository', () async {
      final useCase = SwitchHouseholdUseCase(repository);
      await useCase('h-2');

      expect(repository.switchedHouseholdId, 'h-2');
    });
  });
}
