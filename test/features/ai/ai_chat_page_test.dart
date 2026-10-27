import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/ai/presentation/pages/ai_chat_page.dart';
import 'package:foora/features/ai/domain/entities/ai_action.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_message.dart';
import 'package:foora/features/ai/domain/entities/ai_chat_session.dart';
import 'package:foora/features/ai/domain/entities/ai_assistant_response.dart';
import 'package:foora/features/ai/domain/repositories/ai_repository.dart';
import 'package:foora/features/ai/domain/usecases/send_ai_query.dart';
import 'package:foora/features/ai/presentation/providers/ai_provider.dart';
import 'package:foora/features/ai/presentation/widgets/ai_chat_history_list.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _SuccessfulAiRepository implements AiRepository {
  @override
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) => const Stream.empty();

  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
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
    required String sessionId,
  }) => const Stream.empty();

  @override
  Stream<List<AiChatSession>> watchSessions({
    required String userId,
    required String householdId,
  }) => Stream.value(const []);
}

/// Answers with a reply taller than a phone screen.
class _LongAnswerRepository extends _SuccessfulAiRepository {
  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async => AiAssistantResponse(
    message: AiChatMessage(
      id: '$requestId-assistant',
      content: List.generate(40, (i) => 'Dòng $i của câu trả lời.').join('\n'),
      isUser: false,
      timestamp: DateTime.now(),
    ),
    quota: const AiAssistantQuota(used: 1, limit: 5, day: '2026-10-25'),
  );
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

  test('glued cumulative speech partials collapse to the last one', () {
    expect(collapseRepeatedSpeech('tôitôi cótôi có trứng'), 'tôi có trứng');
    expect(
      collapseRepeatedSpeech('thêm 2 quả trứngthêm 2 quả trứng'),
      'thêm 2 quả trứng',
    );
    expect(collapseRepeatedSpeech('  tôi có trứng '), 'tôi có trứng');
    expect(collapseRepeatedSpeech('từ từ thôi'), 'từ từ thôi');
    expect(collapseRepeatedSpeech('banana'), 'banana');
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

  testWidgets('new chat clears the conversation back to suggestions', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _page([
        currentUserProvider.overrideWith((ref) => _householdUser()),
        aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
        sendAiQueryProvider.overrideWith(
          (ref) => SendAiQuery(_SuccessfulAiRepository()),
        ),
      ]),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tủ còn gì?');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();
    expect(find.text('Tôi đã lập phiếu nhập.'), findsOneWidget);

    await tester.tap(find.byTooltip('Cuộc trò chuyện mới'));
    await tester.pumpAndSettle();
    expect(find.text('Tôi đã lập phiếu nhập.'), findsNothing);
    expect(
      find.text('Trong tủ còn thực phẩm nào sắp hết hạn?'),
      findsOneWidget,
    );
  });

  testWidgets('a follow-up chip is sent at once', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _page([
        currentUserProvider.overrideWith((ref) => _householdUser()),
        aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
        sendAiQueryProvider.overrideWith(
          (ref) => SendAiQuery(_SuccessfulAiRepository()),
        ),
      ]),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tủ còn gì?');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tủ còn gì sắp hết hạn?'));
    await tester.pumpAndSettle();
    // The question is now a sent bubble, answered without another tap.
    expect(
      find.descendant(
        of: find.byType(SelectableText),
        matching: find.text('Tủ còn gì sắp hết hạn?'),
      ),
      findsOneWidget,
    );
    expect(find.text('Tôi đã lập phiếu nhập.'), findsNWidgets(2));
  });

  testWidgets('a long answer opens at its question, a short one at the end', (
    tester,
  ) async {
    _usePhoneSize(tester);
    Future<void> ask(AiRepository repository) async {
      await tester.pumpWidget(
        _page([
          currentUserProvider.overrideWith((ref) => _householdUser()),
          aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
          sendAiQueryProvider.overrideWith((ref) => SendAiQuery(repository)),
        ]),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Tủ còn gì?');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pumpAndSettle();
    }

    await ask(_LongAnswerRepository());
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    final question = find.descendant(
      of: find.byType(SelectableText),
      matching: find.text('Tủ còn gì?'),
    );
    expect(question, findsOneWidget);
    expect(tester.getTopLeft(question).dy, greaterThanOrEqualTo(listTop));
    expect(
      tester.getTopLeft(question).dy,
      lessThan(listTop + 60),
      reason: 'the question sits at the top so the answer reads downwards',
    );

    await tester.pumpWidget(const SizedBox());
    await ask(_SuccessfulAiRepository());
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller!.offset, 0, reason: 'a short turn stays at the end');
  });

  testWidgets('used-up quota locks the composer and offers an upgrade', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _page([
        currentUserProvider.overrideWith((ref) => _householdUser()),
        aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
      ], quota: const AiAssistantQuota(used: 5, limit: 5, day: '2026-10-27')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bạn đã dùng hết lượt hỏi AI hôm nay'), findsOneWidget);
    expect(find.text('Nâng cấp gói'), findsOneWidget);
    final composer = tester.widget<TextField>(find.byType(TextField));
    expect(composer.readOnly, isTrue);
    await tester.enterText(find.byType(TextField), 'Tủ còn gì?');
    await tester.pump();
    final send = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Gửi câu hỏi'),
        matching: find.byType(IconButton),
      ),
    );
    expect(send.onPressed, isNull);
  });

  testWidgets('history sheet reopens an earlier conversation', (tester) async {
    _usePhoneSize(tester);
    final oldAnswer = AiChatMessage(
      id: 'old-assistant',
      content: 'Còn 2 quả trứng.',
      isUser: false,
      timestamp: DateTime(2026, 10, 20),
    );
    await tester.pumpWidget(
      _page([
        currentUserProvider.overrideWith((ref) => _householdUser()),
        aiChatHistoryProvider.overrideWith((ref) {
          final sessionId = ref.watch(
            aiChatProvider.select((chat) => chat.sessionId),
          );
          return Stream.value(sessionId == 'old' ? [oldAnswer] : const []);
        }),
        aiChatSessionsProvider.overrideWith(
          (ref) => Stream.value([
            AiChatSession(
              id: 'old',
              title: 'Tủ còn trứng không?',
              lastMessage: 'Còn 2 quả trứng.',
              updatedAt: DateTime(2026, 10, 20),
            ),
          ]),
        ),
      ]),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Lịch sử trò chuyện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tủ còn trứng không?'));
    await tester.pumpAndSettle();
    expect(find.text('Còn 2 quả trứng.'), findsOneWidget);
  });

  testWidgets('composer stays above the on-screen keyboard', (tester) async {
    _usePhoneSize(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _page([
        currentUserProvider.overrideWith((ref) => _householdUser()),
        aiChatHistoryProvider.overrideWith((ref) => Stream.value(const [])),
      ]),
    );
    await tester.pump();
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(844 - 300));
  });

  test('session time label is short and relative', () {
    final now = DateTime(2026, 10, 26, 9);
    expect(aiSessionTimeLabel(DateTime(2026, 10, 26, 8, 5), now), '08:05');
    expect(aiSessionTimeLabel(DateTime(2026, 10, 25, 22), now), 'Hôm qua');
    expect(aiSessionTimeLabel(DateTime(2026, 3, 4), now), '04/03');
  });
}

User _householdUser() => User(
  id: 'user',
  fullName: 'Test',
  email: 'test@example.com',
  activeHouseholdId: 'house',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _page(List<Override> overrides, {AiAssistantQuota? quota}) =>
    ProviderScope(
      overrides: [
        aiQuotaProvider.overrideWith((ref) => Stream.value(quota)),
        activeHouseholdInventoryStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => const MaterialApp(home: AiChatPage()),
      ),
    );
