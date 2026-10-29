import '../entities/ai_assistant_response.dart';
import '../repositories/ai_repository.dart';

class SendAiQuery {
  const SendAiQuery(this.repository);

  final AiRepository repository;

  Future<AiAssistantResponse> call({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 1000) {
      throw ArgumentError('Câu hỏi phải có từ 1 đến 1000 ký tự.');
    }
    return repository.sendMessage(
      householdId: householdId,
      sessionId: sessionId,
      requestId: requestId,
      message: normalized,
      inputMode: inputMode,
    );
  }
}
