import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/data/datasources/ai_remote_datasource.dart';
import 'package:foora/features/ai/data/repositories/ai_repository_impl.dart';

class _FakeRemote implements AiRemoteDataSource {
  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String householdId,
  }) => Stream.value([
    {
      'id': 'message-assistant',
      'isUser': false,
      'content': 'Món trứng hấp',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 25)),
      'recipes': [
        {
          'title': 'Trứng hấp',
          'usesRefs': ['batch-1'],
          'usedIngredients': ['Trứng'],
          'missingIngredients': ['Hành'],
          'steps': ['Đánh trứng', 'Hấp chín'],
        },
      ],
      'actions': [
        {
          'actionId': 'action-1',
          'type': 'consume',
          'name': 'Trứng',
          'quantity': 2,
          'unit': 'quả',
          'reviewState': 'ready',
          'resolution': 'pending',
          'candidateBatches': [
            {
              'itemId': 'batch-1',
              'name': 'Trứng',
              'quantity': 3,
              'unit': 'quả',
              'expirationDate': '2026-10-26',
            },
          ],
        },
      ],
      'actionStatus': 'proposed',
    },
  ]);

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async => {
    'messageId': 'message-assistant',
    'reply': 'Món trứng hấp',
    'recipes': [
      {
        'title': 'Trứng hấp',
        'usesRefs': ['batch-1'],
        'usedIngredients': ['Trứng'],
        'missingIngredients': [],
        'steps': ['Hấp chín'],
      },
    ],
    'actions': [],
    'quota': {'used': 1, 'limit': 10, 'day': '2026-10-25'},
  };

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async => {'messageId': messageId, 'actionStatus': 'applied'};
}

void main() {
  test('maps structured recipes and action status from saved chat', () async {
    final repository = AiRepositoryImpl(_FakeRemote());
    final history = await repository
        .watchMessages(userId: 'user', householdId: 'household')
        .first;
    expect(history.single.recipes.single.usesRefs, ['batch-1']);
    expect(history.single.recipes.single.missingIngredients, ['Hành']);
    expect(
      history.single.actions.single.candidateBatches.single.itemId,
      'batch-1',
    );
    expect(history.single.actionStatus, 'proposed');
  });

  test('maps recipe returned immediately by callable', () async {
    final repository = AiRepositoryImpl(_FakeRemote());
    final response = await repository.sendMessage(
      householdId: 'household',
      requestId: 'request',
      message: 'Hôm nay nấu gì?',
      inputMode: 'voice',
    );
    expect(response.message.recipes.single.title, 'Trứng hấp');
    expect(response.quota.remaining, 9);
  });
}
