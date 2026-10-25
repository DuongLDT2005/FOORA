import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/presentation/pages/ai_chat_page.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/send_ai_query.dart';
import 'package:foora/features/ai/presentation/providers/ai_provider.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _SuccessfulAiRepository implements AiRepository {
  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async => AiAssistantResponse(
    message: AiChatMessage(
      id: '$requestId-assistant',
      content: 'Tôi đã lập phiếu nhập.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
    quota: const AiAssistantQuota(used: 1, limit: 5, day: '2026-10-25'),
  );

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) => throw UnimplementedError();

  @override
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String householdId,
  }) => const Stream.empty();
}

void main() {
  test('speech recognition always requests Vietnamese', () {
    final englishOnly = [LocaleName('en-US', 'English')];
    expect(vietnameseSpeechLocale(englishOnly, isWeb: true), 'vi-VN');
    expect(vietnameseSpeechLocale(englishOnly, isWeb: false), 'vi-VN');
    expect(
      vietnameseSpeechLocale([
        LocaleName('en-US', 'English'),
        LocaleName('vi_VN', 'Tiếng Việt'),
      ], isWeb: false),
      'vi_VN',
    );
  });

  testWidgets('sent text leaves the composer and can be restored for editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => const MaterialApp(home: AiChatPage()),
        ),
      ),
    );
    await tester.pump();

    const question = 'Trong tủ còn gì?';
    final composer = find.byType(TextField);
    await tester.enterText(composer, question);
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pump();

    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
    expect(find.text(question), findsOneWidget);

    await tester.tap(find.text('Sửa câu hỏi'));
    await tester.pump();
    expect(tester.widget<TextField>(composer).controller!.text, question);
  });

  testWidgets('Enter submits the chat message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => const MaterialApp(home: AiChatPage()),
        ),
      ),
    );
    await tester.pump();

    const question = 'Tủ còn gì?';
    final composer = find.byType(TextField);
    await tester.enterText(composer, question);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
    expect(find.text(question), findsOneWidget);
  });

  testWidgets('inventory request stays in chat while composer clears', (
    tester,
  ) async {
    final now = DateTime(2026);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => User(
              id: 'user',
              fullName: 'Test',
              email: 'test@example.com',
              activeHouseholdId: 'house',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
          sendAiQueryProvider.overrideWith(
            (ref) => SendAiQuery(_SuccessfulAiRepository()),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => const MaterialApp(home: AiChatPage()),
        ),
      ),
    );
    await tester.pump();

    const request = 'Tôi vừa mua 1 kg thịt bò';
    final composer = find.byType(TextField);
    await tester.enterText(composer, request);
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
    expect(find.text(request), findsOneWidget);
    expect(find.text('Tôi đã lập phiếu nhập.'), findsOneWidget);
  });

  testWidgets('renders a saved inventory proposal in the chat timeline', (
    tester,
  ) async {
    final proposal = AiChatMessage(
      id: 'proposal-assistant',
      content: 'Tôi đã lập phiếu nhập 2 món.',
      isUser: false,
      timestamp: DateTime(2026),
      actionStatus: 'proposed',
      actions: const [
        AiAction(
          actionId: 'pork',
          type: 'add_inventory',
          name: 'Thịt heo',
          quantity: 1,
          unit: 'kg',
          candidateBatches: [],
          reviewState: 'needsReview',
          resolution: 'pending',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          aiChatHistoryProvider.overrideWith((ref) => Stream.value([proposal])),
          foodCategoriesProvider.overrideWith((ref) async => []),
          storageLocationsProvider.overrideWith((ref) async => []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => const MaterialApp(home: AiChatPage()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Phiếu nhập tủ lạnh'), findsOneWidget);
    expect(find.text('Xác nhận nhập kho'), findsOneWidget);
  });
}
