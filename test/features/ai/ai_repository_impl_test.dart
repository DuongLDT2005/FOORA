import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/data/datasources/ai_remote_datasource.dart';
import 'package:foora/features/ai/data/repositories/ai_repository_impl.dart';

class _FakeRemote implements AiRemoteDataSource {
  @override
  Stream<Map<String, dynamic>> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> watchSessions({
    required String userId,
    required String householdId,
  }) => Stream.value([
    {
      'id': 'session-1',
      'title': 'Hôm nay nấu gì?',
      'lastMessage': 'Gợi ý trứng hấp.',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 25)),
    },
    {'id': 'session-2', 'title': '  '},
  ]);

  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String userId,
    required String sessionId,
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
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async => {
    'messageId': 'message-assistant',
    'reply': 'Món trứng hấp',
    'recipes': [
      {
        'title': 'Trứng hấp',
        'servings': 2,
        'ingredients': [
          {'name': 'Trứng', 'quantity': 2, 'unit': 'quả', 'itemId': 'batch-1'},
          {'name': 'Hành lá', 'quantity': 1, 'unit': 'nhánh'},
        ],
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
  test('maps saved chat sessions with a fallback title', () async {
    final sessions = await AiRepositoryImpl(
      _FakeRemote(),
    ).watchSessions(userId: 'user', householdId: 'household').first;
    expect(sessions.map((session) => session.title), [
      'Hôm nay nấu gì?',
      'Cuộc trò chuyện',
    ]);
    expect(sessions.first.lastMessage, 'Gợi ý trứng hấp.');
    expect(sessions.first.updatedAt, DateTime(2026, 10, 25));
  });

  test('maps legacy recipes and action status from saved chat', () async {
    final repository = AiRepositoryImpl(_FakeRemote());
    final history = await repository
        .watchMessages(userId: 'user', sessionId: 'session')
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
      sessionId: 'session',
      requestId: 'request',
      message: 'Hôm nay nấu gì?',
      inputMode: 'voice',
    );
    final recipe = response.message.recipes.single;
    expect(recipe.title, 'Trứng hấp');
    expect(recipe.servings, 2);
    expect(recipe.ingredients.first.quantity, 2);
    expect(recipe.ingredients.first.inInventory, isTrue);
    expect(recipe.missingIngredients, ['Hành lá']);
    expect(response.quota.remaining, 9);
  });
}
