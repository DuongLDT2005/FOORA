import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../data/datasources/ai_remote_datasource.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_chat_session.dart';
import '../../domain/entities/ai_assistant_response.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/send_ai_query.dart';
import '../../domain/usecases/apply_ai_actions.dart';
import '../../domain/usecases/watch_ai_quota.dart';

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

final applyAiActionsProvider = Provider<ApplyAiActions>((ref) {
  return ApplyAiActions(ref.watch(aiRepositoryProvider));
});

final watchAiQuotaProvider = Provider<WatchAiQuota>((ref) {
  return WatchAiQuota(ref.watch(aiRepositoryProvider));
});

/// Today's assistant quota, live; null while the plan is still unknown.
final aiQuotaProvider = StreamProvider.autoDispose<AiAssistantQuota?>((ref) {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return Stream.value(null);
  final subscription = ref.watch(premiumSubscriptionProvider);
  if (!subscription.hasValue) return Stream.value(null);
  // Same plan resolution as the backend: an entitled subscription, else Free.
  final active = subscription.value;
  final membershipId = active != null && active.isActive
      ? active.membershipId
      : 'free';
  return ref
      .watch(watchAiQuotaProvider)
      .call(userId: userId, membershipId: membershipId);
});

/// Messages of the session currently open in [aiChatProvider].
final aiChatHistoryProvider = StreamProvider.autoDispose<List<AiChatMessage>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final householdId = user?.activeHouseholdId;
  final sessionId = ref.watch(aiChatProvider.select((chat) => chat.sessionId));
  if (user == null || householdId == null || householdId.isEmpty) {
    return Stream.value(const []);
  }
  return ref
      .watch(aiRepositoryProvider)
      .watchMessages(userId: user.id, sessionId: sessionId);
});

/// Saved conversations of the active household, newest first.
final aiChatSessionsProvider = StreamProvider.autoDispose<List<AiChatSession>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final householdId = user?.activeHouseholdId;
  if (user == null || householdId == null || householdId.isEmpty) {
    return Stream.value(const []);
  }
  return ref
      .watch(aiRepositoryProvider)
      .watchSessions(userId: user.id, householdId: householdId);
});

class AiChatState {
  const AiChatState({
    required this.sessionId,
    this.messages = const [],
    this.pendingMessage,
    this.pendingRequestId,
    this.pendingInputMode,
    this.isSending = false,
    this.error,
    this.quota,
  });

  /// Conversation the next question belongs to; created on the client.
  final String sessionId;
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
  AiChatNotifier(this.ref) : super(AiChatState(sessionId: newUuidV4()));

  final Ref ref;

  /// Starts an empty conversation; earlier turns no longer reach the model.
  void startNewSession() => _switchSession(newUuidV4());

  void openSession(String sessionId) {
    if (sessionId != state.sessionId) _switchSession(sessionId);
  }

  void _switchSession(String sessionId) {
    if (state.isSending) return;
    state = AiChatState(sessionId: sessionId, quota: state.quota);
  }

  Future<bool> send(String text, {required String inputMode}) async {
    if (state.isSending || state.pendingMessage != null) return false;
    final message = text.trim();
    if (message.isEmpty || message.length > 1000) return false;
    final requestId = newUuidV4();
    state = AiChatState(
      sessionId: state.sessionId,
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
      sessionId: state.sessionId,
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
    state = AiChatState(
      sessionId: state.sessionId,
      messages: state.messages,
      quota: state.quota,
    );
  }

  Future<bool> _submitPending() async {
    final householdId = ref.read(currentUserProvider)?.activeHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      state = AiChatState(
        sessionId: state.sessionId,
        messages: state.messages,
        pendingMessage: state.pendingMessage,
        pendingRequestId: state.pendingRequestId,
        pendingInputMode: state.pendingInputMode,
        error: 'Chưa có tủ lạnh gia đình để trợ lý tra cứu.',
        quota: state.quota,
      );
      return false;
    }
    // Taken before the call so the question sorts above its answer until
    // the saved messages arrive from Firestore.
    final sentAt = DateTime.now();
    try {
      final response = await ref.read(sendAiQueryProvider)(
        householdId: householdId,
        sessionId: state.sessionId,
        requestId: state.pendingRequestId!,
        message: state.pendingMessage!,
        inputMode: state.pendingInputMode!,
      );
      if (!mounted) return true;
      final userMessage = AiChatMessage(
        id: '${state.pendingRequestId}-user',
        content: state.pendingMessage!,
        isUser: true,
        timestamp: sentAt,
      );
      state = AiChatState(
        sessionId: state.sessionId,
        messages: [...state.messages, userMessage, response.message],
        quota: response.quota,
      );
      return true;
    } on Failure catch (failure) {
      if (!mounted) return false;
      state = AiChatState(
        sessionId: state.sessionId,
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
        sessionId: state.sessionId,
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
}

/// Random UUID v4, the format the backend accepts for request and session IDs.
String newUuidV4() {
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
