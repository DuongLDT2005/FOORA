import '../entities/ai_chat_message.dart';
import '../entities/ai_assistant_response.dart';

abstract class AiRepository {
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String householdId,
  });

  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  });

  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  });
}
