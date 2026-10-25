import '../repositories/ai_repository.dart';

class ApplyAiActions {
  const ApplyAiActions(this.repository);

  final AiRepository repository;

  Future<Map<String, dynamic>> call({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) {
    if (decisions.isEmpty || decisions.length > 10) {
      throw ArgumentError('Danh sách quyết định phải có từ 1 đến 10 action.');
    }
    return repository.applyActions(messageId: messageId, decisions: decisions);
  }
}
