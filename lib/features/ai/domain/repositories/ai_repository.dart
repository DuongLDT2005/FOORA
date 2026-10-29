import '../entities/ai_chat_message.dart';
import '../entities/ai_chat_session.dart';
import '../entities/ai_assistant_response.dart';

abstract class AiRepository {
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String sessionId,
  });

  Stream<List<AiChatSession>> watchSessions({
    required String userId,
    required String householdId,
  });

  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  });

  /// Today's assistant usage and the plan's daily limit (null = unlimited).
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  });

  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  });
}
