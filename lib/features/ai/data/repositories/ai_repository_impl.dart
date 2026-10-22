import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_assistant_response.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_remote_datasource.dart';

class AiRepositoryImpl implements AiRepository {
  const AiRepositoryImpl(this.remoteDataSource);

  final AiRemoteDataSource remoteDataSource;

  @override
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String householdId,
  }) {
    return remoteDataSource
        .watchMessages(userId: userId, householdId: householdId)
        .map(
          (records) => records.map((data) {
            final createdAt = data['createdAt'];
            return AiChatMessage(
              id: data['id'] as String,
              content: data['content'] is String
                  ? data['content'] as String
                  : '',
              isUser: data['isUser'] == true,
              timestamp: createdAt is Timestamp
                  ? createdAt.toDate()
                  : DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async {
    try {
      final data = await remoteDataSource.sendMessage(
        householdId: householdId,
        requestId: requestId,
        message: message,
        inputMode: inputMode,
      );
      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ServerException('Trợ lý AI trả về nội dung không hợp lệ.');
      }
      final quotaData = data['quota'];
      if (quotaData is! Map ||
          quotaData['used'] is! num ||
          quotaData['day'] is! String ||
          (quotaData['limit'] != null && quotaData['limit'] is! num)) {
        throw const ServerException('Hạn mức AI trả về không hợp lệ.');
      }
      return AiAssistantResponse(
        message: AiChatMessage(
          id: data['messageId'] is String
              ? data['messageId'] as String
              : requestId,
          content: reply.trim(),
          isUser: false,
          timestamp: DateTime.now(),
        ),
        quota: AiAssistantQuota(
          used: (quotaData['used'] as num).toInt(),
          limit: (quotaData['limit'] as num?)?.toInt(),
          day: quotaData['day'] as String,
        ),
      );
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }
}
