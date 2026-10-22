import 'ai_chat_message.dart';

class AiAssistantQuota {
  const AiAssistantQuota({
    required this.used,
    required this.limit,
    required this.day,
  });

  final int used;
  final int? limit;
  final String day;

  int? get remaining =>
      limit == null ? null : (limit! - used).clamp(0, limit!).toInt();
}

class AiAssistantResponse {
  const AiAssistantResponse({required this.message, required this.quota});

  final AiChatMessage message;
  final AiAssistantQuota quota;
}
