import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';

abstract class AiRemoteDataSource {
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String sessionId,
  });

  Stream<List<Map<String, dynamic>>> watchSessions({
    required String userId,
    required String householdId,
  });

  Future<Map<String, dynamic>> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  });

  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  });

  /// `used` from today's usage counter and `limit` from the plan.
  Stream<Map<String, dynamic>> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  });
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  const AiRemoteDataSourceImpl(this.functions, this.firestore);

  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;

  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String sessionId,
  }) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.aiChats)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchSessions({
    required String userId,
    required String householdId,
  }) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.aiSessions)
        .where('householdId', isEqualTo: householdId)
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  @override
  Stream<Map<String, dynamic>> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) async* {
    final plan = await firestore
        .collection(FirestoreConstants.memberships)
        .doc(membershipId)
        .get();
    final limit = plan.data()?['aiAssistantDailyQuota'];
    yield* firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.aiUsageDays)
        .doc(day)
        .snapshots()
        .map(
          (snapshot) => {
            'used': snapshot.data()?['used'] ?? 0,
            'limit': limit is num ? limit : null,
          },
        );
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async {
    try {
      final response = await functions
          .httpsCallable(
            'aiAssistant',
            options: HttpsCallableOptions(
              timeout: AppConstants.aiAssistantTimeout,
            ),
          )
          .call({
            'householdId': householdId,
            'sessionId': sessionId,
            'requestId': requestId,
            'message': message,
            'inputMode': inputMode,
          });
      final envelope = Map<String, dynamic>.from(response.data as Map);
      if (envelope['success'] != true || envelope['data'] is! Map) {
        throw const ServerException('Không thể nhận câu trả lời từ trợ lý AI.');
      }
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on FirebaseFunctionsException catch (error) {
      AppLogger.w('aiAssistant failed: ${error.code} ${error.message}');
      switch (error.code) {
        case 'resource-exhausted':
          throw const ServerException('Bạn đã hết lượt hỏi AI hôm nay.');
        case 'invalid-argument':
          throw ServerException(
            error.message ?? 'Câu hỏi hoặc thông tin phiên không hợp lệ.',
            error.code,
          );
        case 'deadline-exceeded':
          throw ServerException(
            'Trợ lý AI phản hồi quá lâu. Vui lòng thử lại.',
            error.code,
          );
        case 'unauthenticated':
          throw ServerException(
            'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
            error.code,
          );
        case 'permission-denied':
          throw const ServerException('Bạn không có quyền hỏi về tủ lạnh này.');
        case 'failed-precondition':
          throw ServerException(
            error.message ?? 'Câu hỏi chưa thể xử lý. Vui lòng thử lại.',
            error.code,
          );
        case 'internal':
        case 'unavailable':
          throw ServerException(
            error.message ?? 'Dịch vụ AI tạm thời chưa sẵn sàng.',
            error.code,
          );
        case 'not-found':
          throw const ServerException('Dịch vụ trợ lý AI chưa sẵn sàng.');
        default:
          throw ServerException(
            'Không thể kết nối trợ lý AI (${error.code}). Vui lòng thử lại.',
            error.code,
          );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ServerException('Không thể nhận câu trả lời từ trợ lý AI.');
    }
  }

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async {
    try {
      final response = await functions.httpsCallable('applyAiActions').call({
        'messageId': messageId,
        'decisions': decisions,
      });
      final envelope = Map<String, dynamic>.from(response.data as Map);
      if (envelope['success'] != true || envelope['data'] is! Map) {
        throw const ServerException('Không thể xác nhận cập nhật kho.');
      }
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on FirebaseFunctionsException catch (error) {
      throw ServerException(
        error.message ?? 'Không thể xác nhận cập nhật kho.',
        error.code,
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ServerException('Không thể xác nhận cập nhật kho.');
    }
  }
}
