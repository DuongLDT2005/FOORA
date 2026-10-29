import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_session.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/send_ai_query.dart';

class _FakeAiRepository implements AiRepository {
  @override
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) => const Stream.empty();

  String? sentMessage;
  String? sentRequestId;
  String? sentInputMode;

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async => {};

  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async {
    sentMessage = message;
    sentRequestId = requestId;
    sentInputMode = inputMode;
    return AiAssistantResponse(
      message: AiChatMessage(
        id: 'reply',
        content: 'Còn 2 quả trứng.',
        isUser: false,
        timestamp: DateTime(2026),
      ),
      quota: const AiAssistantQuota(used: 1, limit: 10, day: '2026-10-23'),
    );
  }

  @override
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String sessionId,
  }) => Stream.value(const []);

  @override
  Stream<List<AiChatSession>> watchSessions({
    required String userId,
    required String householdId,
  }) => Stream.value(const []);
}

void main() {
  test('trims a voice transcript and keeps its request ID', () async {
    final repository = _FakeAiRepository();
    final useCase = SendAiQuery(repository);

    final reply = await useCase(
      householdId: 'home',
      sessionId: 'session-1',
      requestId: 'request-1',
      message: '  Còn bao nhiêu trứng?  ',
      inputMode: 'voice',
    );

    expect(repository.sentMessage, 'Còn bao nhiêu trứng?');
    expect(repository.sentRequestId, 'request-1');
    expect(repository.sentInputMode, 'voice');
    expect(reply.message.content, 'Còn 2 quả trứng.');
    expect(reply.quota.remaining, 9);
  });

  test('rejects empty and oversized questions before a backend call', () async {
    final repository = _FakeAiRepository();
    final useCase = SendAiQuery(repository);

    expect(
      () => useCase(
        householdId: 'home',
        sessionId: 'session-1',
        requestId: 'request-1',
        message: '   ',
        inputMode: 'text',
      ),
      throwsArgumentError,
    );
    expect(
      () => useCase(
        householdId: 'home',
        sessionId: 'session-1',
        requestId: 'request-2',
        message: 'a' * 1001,
        inputMode: 'text',
      ),
      throwsArgumentError,
    );
    expect(repository.sentMessage, isNull);
  });
}
