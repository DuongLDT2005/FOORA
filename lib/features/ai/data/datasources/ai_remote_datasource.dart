import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';

abstract class AiRemoteDataSource {
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String householdId,
  });

  Future<Map<String, dynamic>> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  });
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  const AiRemoteDataSourceImpl(this.functions, this.firestore);

  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;

  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String householdId,
  }) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.aiChats)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.data()['householdId'] == householdId)
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async {
    try {
      final response = await functions.httpsCallable('aiAssistant').call({
        'householdId': householdId,
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
      switch (error.code) {
        case 'resource-exhausted':
          throw const ServerException('Bạn đã hết lượt hỏi AI hôm nay.');
        case 'permission-denied':
          throw const ServerException('Bạn không có quyền hỏi về tủ lạnh này.');
        case 'failed-precondition':
          throw ServerException(
            error.message ?? 'Câu hỏi chưa thể xử lý. Vui lòng thử lại.',
          );
        case 'not-found':
          throw const ServerException('Dịch vụ trợ lý AI chưa sẵn sàng.');
        default:
          throw const ServerException(
            'Không thể kết nối trợ lý AI. Vui lòng thử lại.',
          );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ServerException('Không thể nhận câu trả lời từ trợ lý AI.');
    }
  }
}
