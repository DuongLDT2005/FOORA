import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_invitation.dart';
import '../../domain/entities/household_invitation_info.dart';
import '../../domain/entities/household_member.dart';
import '../../domain/repositories/household_repository.dart';
import '../datasources/household_remote_datasource.dart';

class HouseholdRepositoryImpl implements HouseholdRepository {
  final HouseholdRemoteDataSource remoteDataSource;

  HouseholdRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return remoteDataSource.watchHousehold(householdId).handleError(_toFailure);
  }

  @override
  Stream<List<Household>> watchUserHouseholds(String userId) {
    return remoteDataSource.watchUserHouseholds(userId).handleError(_toFailure);
  }

  /// Maps stream errors (e.g. permission-denied right after being removed
  /// from a household) to domain failures instead of raw exceptions.
  Never _toFailure(Object error) {
    if (error is Failure) throw error;
    if (error is AppException) throw Failure.fromException(error);
    throw ServerFailure('Không thể đồng bộ dữ liệu gia đình: $error');
  }

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    try {
      return await remoteDataSource.getHouseholdMembers(householdId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi tải thành viên: $e');
    }
  }

  @override
  Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  }) async {
    try {
      await remoteDataSource.updateHouseholdName(
        householdId: householdId,
        name: name,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi cập nhật tên: $e');
    }
  }

  @override
  Future<HouseholdInvitation> generateInvitation({
    required String householdId,
  }) async {
    try {
      return await remoteDataSource.generateInvitation(
        householdId: householdId,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi tạo mã lời mời: $e');
    }
  }

  @override
  Future<HouseholdInvitation?> getActiveInvitation(String householdId) async {
    try {
      return await remoteDataSource.getActiveInvitation(householdId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi kiểm tra mã lời mời: $e');
    }
  }

  @override
  Future<void> revokeInvitation({
    required String householdId,
    required String invitationId,
  }) async {
    try {
      await remoteDataSource.revokeInvitation(
        householdId: householdId,
        invitationId: invitationId,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi thu hồi mã: $e');
    }
  }

  @override
  Future<HouseholdInvitationInfo> getInvitationInfo(String code) async {
    try {
      return await remoteDataSource.getInvitationInfo(code);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi kiểm tra mã lời mời: $e');
    }
  }

  @override
  Future<void> joinHousehold(String code) async {
    try {
      await remoteDataSource.joinHousehold(code);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi tham gia gia đình: $e');
    }
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  }) async {
    try {
      await remoteDataSource.removeMember(
        householdId: householdId,
        memberUserId: memberUserId,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi xóa thành viên: $e');
    }
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    try {
      await remoteDataSource.leaveHousehold(householdId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi rời gia đình: $e');
    }
  }

  @override
  Future<void> switchHousehold(String householdId) async {
    try {
      await remoteDataSource.switchHousehold(householdId);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure('Lỗi không xác định khi chuyển gia đình: $e');
    }
  }
}
