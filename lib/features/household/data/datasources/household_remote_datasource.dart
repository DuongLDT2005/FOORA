import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/household_invitation_info_model.dart';
import '../models/household_invitation_model.dart';
import '../models/household_member_model.dart';
import '../models/household_model.dart';

abstract class HouseholdRemoteDataSource {
  Stream<HouseholdModel?> watchHousehold(String householdId);
  Stream<List<HouseholdModel>> watchUserHouseholds(String userId);
  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId);
  Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  });
  Future<HouseholdInvitationModel> generateInvitation({
    required String householdId,
    int expiresInDays = 7,
  });
  Future<HouseholdInvitationModel?> getActiveInvitation(String householdId);
  Future<void> revokeInvitation({
    required String householdId,
    required String invitationId,
  });
  Future<HouseholdInvitationInfoModel> getInvitationInfo(String code);
  Future<void> joinHousehold(String code);
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  });
  Future<void> leaveHousehold(String householdId);
  Future<void> switchHousehold(String householdId);
}

class HouseholdRemoteDataSourceImpl implements HouseholdRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  HouseholdRemoteDataSourceImpl({
    required this.firestore,
    required this.functions,
  });

  @override
  Stream<HouseholdModel?> watchHousehold(String householdId) {
    if (householdId.isEmpty) return Stream.value(null);
    return firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return HouseholdModel.fromFirestore(doc);
        });
  }

  @override
  Stream<List<HouseholdModel>> watchUserHouseholds(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return firestore
        .collection(FirestoreConstants.households)
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HouseholdModel.fromFirestore(doc))
              .toList();
        });
  }

  @override
  Future<List<HouseholdMemberModel>> getHouseholdMembers(
    String householdId,
  ) async {
    try {
      final callable = functions.httpsCallable('getHouseholdMembers');
      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
      });

      final data = response.data;
      final rawList = data['data'] as List<dynamic>? ?? [];
      return rawList
          .map(
            (e) => HouseholdMemberModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể tải danh sách thành viên.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tải thành viên gia đình: $e');
    }
  }

  @override
  Future<void> updateHouseholdName({
    required String householdId,
    required String name,
  }) async {
    try {
      final callable = functions.httpsCallable('updateHouseholdName');
      await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'name': name.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể cập nhật tên gia đình.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi cập nhật tên gia đình: $e');
    }
  }

  @override
  Future<HouseholdInvitationModel> generateInvitation({
    required String householdId,
    int expiresInDays = 7,
  }) async {
    try {
      final callable = functions.httpsCallable('generateHouseholdInvitation');
      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'expiresInDays': expiresInDays,
      });

      final data = response.data;
      final invData = data['data'] as Map<dynamic, dynamic>?;
      if (invData == null) {
        throw const ServerException('Không nhận được dữ liệu mã lời mời.');
      }
      return HouseholdInvitationModel.fromJson(
        Map<String, dynamic>.from(invData),
      );
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể tạo mã lời mời tham gia.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tạo mã lời mời: $e');
    }
  }

  @override
  Future<HouseholdInvitationModel?> getActiveInvitation(
    String householdId,
  ) async {
    try {
      final callable = functions.httpsCallable('getActiveHouseholdInvitation');
      final response = await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
      });

      final data = response.data;
      final invData = data['data'] as Map<dynamic, dynamic>?;
      if (invData == null) return null;
      return HouseholdInvitationModel.fromJson(
        Map<String, dynamic>.from(invData),
      );
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể kiểm tra mã lời mời.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi kiểm tra mã lời mời: $e');
    }
  }

  @override
  Future<void> revokeInvitation({
    required String householdId,
    required String invitationId,
  }) async {
    try {
      final callable = functions.httpsCallable('revokeHouseholdInvitation');
      await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'invitationId': invitationId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể thu hồi mã lời mời.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi thu hồi mã lời mời: $e');
    }
  }

  @override
  Future<HouseholdInvitationInfoModel> getInvitationInfo(String code) async {
    try {
      final callable = functions.httpsCallable('getHouseholdInvitationInfo');
      final response = await callable.call<Map<String, dynamic>>({
        'code': code.trim().toUpperCase(),
      });

      final data = response.data;
      final infoData = data['data'] as Map<dynamic, dynamic>?;
      if (infoData == null) {
        throw const ServerException('Không nhận được thông tin lời mời.');
      }
      return HouseholdInvitationInfoModel.fromJson(
        Map<String, dynamic>.from(infoData),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw NotFoundException(
          e.message ?? 'Mã lời mời không tồn tại hoặc đã bị thu hồi.',
        );
      }
      throw ServerException(
        e.message ?? 'Không thể kiểm tra thông tin lời mời.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi kiểm tra lời mời: $e');
    }
  }

  @override
  Future<void> joinHousehold(String code) async {
    try {
      final callable = functions.httpsCallable('joinHousehold');
      await callable.call<Map<String, dynamic>>({
        'code': code.trim().toUpperCase(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể tham gia gia đình.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi tham gia gia đình: $e');
    }
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  }) async {
    try {
      final callable = functions.httpsCallable('removeHouseholdMember');
      await callable.call<Map<String, dynamic>>({
        'householdId': householdId,
        'memberUserId': memberUserId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể xóa thành viên khỏi gia đình.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi xóa thành viên: $e');
    }
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    try {
      final callable = functions.httpsCallable('leaveHousehold');
      await callable.call<Map<String, dynamic>>({'householdId': householdId});
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể rời khỏi gia đình.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi rời khỏi gia đình: $e');
    }
  }

  @override
  Future<void> switchHousehold(String householdId) async {
    try {
      final callable = functions.httpsCallable('switchHousehold');
      await callable.call<Map<String, dynamic>>({'householdId': householdId});
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(
        e.message ?? 'Không thể chuyển đổi gia đình hoạt động.',
        e.code,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Lỗi khi chuyển đổi gia đình: $e');
    }
  }
}
