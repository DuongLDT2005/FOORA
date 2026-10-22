import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/ai_remote_datasource.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_assistant_response.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/send_ai_query.dart';

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSourceImpl(
    ref.watch(functionsProvider),
    ref.watch(firestoreProvider),
  );
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(aiRemoteDataSourceProvider));
});

final sendAiQueryProvider = Provider<SendAiQuery>((ref) {
  return SendAiQuery(ref.watch(aiRepositoryProvider));
});

final aiChatHistoryProvider = StreamProvider.autoDispose<List<AiChatMessage>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final householdId = user?.activeHouseholdId;
  if (user == null || householdId == null || householdId.isEmpty) {
    return Stream.value(const []);
  }
  return ref
      .watch(aiRepositoryProvider)
      .watchMessages(userId: user.id, householdId: householdId);
});

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.pendingMessage,
    this.pendingRequestId,
    this.pendingInputMode,
    this.isSending = false,
    this.error,
    this.quota,
  });

  final List<AiChatMessage> messages;
  final String? pendingMessage;
  final String? pendingRequestId;
  final String? pendingInputMode;
  final bool isSending;
  final String? error;
  final AiAssistantQuota? quota;
}

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>((ref) {
      return AiChatNotifier(ref);
    });

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier(this.ref) : super(const AiChatState());

  final Ref ref;

  Future<bool> send(String text, {required String inputMode}) async {
    if (state.isSending || state.pendingMessage != null) return false;
    final message = text.trim();
    if (message.isEmpty || message.length > 1000) return false;
    final requestId = _newRequestId();
    state = AiChatState(
      messages: state.messages,
      pendingMessage: message,
      pendingRequestId: requestId,
      pendingInputMode: inputMode,
      isSending: true,
      quota: state.quota,
    );
    return _submitPending();
  }

  Future<bool> retry() async {
    if (state.isSending || state.pendingRequestId == null) return false;
    state = AiChatState(
      messages: state.messages,
      pendingMessage: state.pendingMessage,
      pendingRequestId: state.pendingRequestId,
      pendingInputMode: state.pendingInputMode,
      isSending: true,
      quota: state.quota,
    );
    return _submitPending();
  }

  void discardPending() {
    if (state.isSending) return;
    state = AiChatState(messages: state.messages, quota: state.quota);
  }

  Future<bool> _submitPending() async {
    final householdId = ref.read(currentUserProvider)?.activeHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      state = AiChatState(
        messages: state.messages,
        pendingMessage: state.pendingMessage,
        pendingRequestId: state.pendingRequestId,
        pendingInputMode: state.pendingInputMode,
        error: 'Chưa có tủ lạnh gia đình để trợ lý tra cứu.',
        quota: state.quota,
      );
      return false;
    }
    try {
      final response = await ref.read(sendAiQueryProvider)(
        householdId: householdId,
        requestId: state.pendingRequestId!,
        message: state.pendingMessage!,
        inputMode: state.pendingInputMode!,
      );
      if (!mounted) return true;
      final userMessage = AiChatMessage(
        id: '${state.pendingRequestId}-user',
        content: state.pendingMessage!,
        isUser: true,
        timestamp: DateTime.now(),
      );
      state = AiChatState(
        messages: [...state.messages, userMessage, response.message],
        quota: response.quota,
      );
      return true;
    } on Failure catch (failure) {
      if (!mounted) return false;
      state = AiChatState(
        messages: state.messages,
        pendingMessage: state.pendingMessage,
        pendingRequestId: state.pendingRequestId,
        pendingInputMode: state.pendingInputMode,
        error: failure.message,
        quota: state.quota,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = AiChatState(
        messages: state.messages,
        pendingMessage: state.pendingMessage,
        pendingRequestId: state.pendingRequestId,
        pendingInputMode: state.pendingInputMode,
        error: 'Không thể gửi câu hỏi. Vui lòng thử lại.',
        quota: state.quota,
      );
      return false;
    }
  }

  String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
