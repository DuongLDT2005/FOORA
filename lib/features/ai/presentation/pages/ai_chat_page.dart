import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../shopping/domain/usecases/build_recipe_shopping_drafts.dart';
import '../../../shopping/presentation/providers/shopping_providers.dart';
import '../../../shopping/presentation/widgets/add_recipe_to_shopping_sheet.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_recipe.dart';
import '../providers/ai_provider.dart';
import '../widgets/ai_chat_history_list.dart';
import '../widgets/ai_chat_suggestions.dart';
import '../widgets/ai_thinking_indicator.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ai_action_review_sheet.dart';
import '../widgets/ai_entry_receipt_card.dart' show aiDisplayNumber;

String vietnameseSpeechLocale(List<LocaleName> locales, {required bool isWeb}) {
  // The web plugin reports only the browser's current language, so its list
  // cannot be used to decide whether Vietnamese recognition is available.
  if (isWeb) return 'vi-VN';
  for (final locale in locales) {
    if (locale.localeId.toLowerCase().replaceAll('_', '-') == 'vi-vn') {
      return locale.localeId;
    }
  }
  for (final locale in locales) {
    if (locale.localeId.toLowerCase().startsWith('vi')) {
      return locale.localeId;
    }
  }
  // Android's online recognizer may support languages absent from locales().
  return 'vi-VN';
}

/// Some recognizers (Chrome on Android, a few OEM engines) report every
/// partial result glued to the earlier ones, e.g. "tôitôi cótôi có trứng".
/// When the text is made only of growing prefixes of its last segment, that
/// segment is the real transcript and is returned; other text is unchanged.
String collapseRepeatedSpeech(String text) {
  final s = text.trim();
  for (var k = 1; k < s.length; k++) {
    // A glued repeat starts right after a non-space without a separator.
    if (s[k - 1].trim().isEmpty || s[k].trim().isEmpty) continue;
    final last = s.substring(k);
    final cuts = <int>[
      for (var i = 0; i < last.length; i++)
        if (last[i] == ' ') i,
      last.length,
    ].reversed;
    var pos = 0;
    while (pos < k) {
      final cut = cuts.firstWhere(
        (c) => c > 0 && pos + c <= k && s.startsWith(last.substring(0, c), pos),
        orElse: () => 0,
      );
      if (cut == 0) break;
      pos += cut;
    }
    // The shortest glued head is peeled first; the rest may hold more.
    if (pos == k) return collapseRepeatedSpeech(last);
  }
  return s;
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _draftMode = 'text';
  String _beforeSpeech = '';

  /// The engine can deliver its final result after listening stops, even
  /// after the draft was sent. Results carry the session they belong to and
  /// are dropped once the composer has moved on.
  int _speechSession = 0;

  /// The list is reversed (offset 0 = newest at the bottom). A long answer
  /// would open at its end, so it is scrolled to start at its question.
  final ScrollController _scroll = ScrollController();
  final GlobalKey _questionKey = GlobalKey();
  final GlobalKey _answerKey = GlobalKey();
  String? _revealQuestionId;
  String? _revealAnswerId;

  @override
  void dispose() {
    _speech.cancel();
    _scroll.dispose();
    _composer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() => _isListening = false);
            context.showToast(
              'Không thể nhận giọng nói. Bạn vẫn có thể gõ câu hỏi.',
              isError: true,
            );
          }
        },
      );
      if (!mounted) return;
      if (!available) {
        context.showToast(
          'Micro chưa sẵn sàng. Hãy kiểm tra quyền truy cập và thử lại.',
          isError: true,
        );
        return;
      }
      final locales = await _speech.locales();
      if (!mounted) return;
      // While the keyboard holds a composing region, rewriting the text makes
      // the IME re-insert its own copy, which duplicates and glues the words.
      _focusNode.unfocus();
      _beforeSpeech = _composer.text.trimRight();
      _draftMode = 'voice';
      final session = ++_speechSession;
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result, session),
        listenOptions: SpeechListenOptions(
          localeId: vietnameseSpeechLocale(locales, isWeb: kIsWeb),
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      if (mounted) setState(() => _isListening = true);
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
        context.showToast(
          'Không thể mở micro. Bạn vẫn có thể gõ câu hỏi.',
          isError: true,
        );
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int session) {
    if (!mounted || session != _speechSession) return;
    final words = collapseRepeatedSpeech(result.recognizedWords);
    final prefix = _beforeSpeech.isEmpty ? '' : '$_beforeSpeech ';
    _composer.value = TextEditingValue(
      text: '$prefix$words',
      selection: TextSelection.collapsed(offset: prefix.length + words.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final chat = ref.read(aiChatProvider);
    if (text.isEmpty ||
        text.length > 1000 ||
        _isListening ||
        chat.isSending ||
        chat.pendingMessage != null) {
      return;
    }
    _focusNode.unfocus();
    _speechSession++;
    final sending = ref
        .read(aiChatProvider.notifier)
        .send(text, inputMode: _draftMode);
    _composer.value = TextEditingValue.empty;
    setState(() => _draftMode = 'text');
    await sending;
  }

  void _editPending() {
    final chat = ref.read(aiChatProvider);
    final message = chat.pendingMessage;
    if (message == null || chat.isSending) return;
    ref.read(aiChatProvider.notifier).discardPending();
    _composer.text = message;
    _composer.selection = TextSelection.collapsed(offset: message.length);
    _draftMode = chat.pendingInputMode ?? 'text';
    _focusNode.requestFocus();
    setState(() {});
  }

  /// After a new answer, brings its question to the top of the list when the
  /// turn is taller than the screen, so it reads from the start. A short turn
  /// stays anchored at the bottom, and a user reading older messages is left
  /// where they are.
  void _revealNewTurn(String questionId, String answerId) {
    if (_scroll.hasClients && _scroll.offset > 48) return;
    setState(() {
      _revealQuestionId = questionId;
      _revealAnswerId = answerId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A very long answer pushes its question out of the built range, so
      // the answer's start is revealed first; that builds the question,
      // which is then brought to the top as well.
      if (_questionKey.currentContext == null &&
          !await _revealAtTop(_answerKey)) {
        return;
      }
      await _revealAtTop(_questionKey);
    });
  }

  /// Scrolls [key]'s widget to the top edge if its top is above the list.
  /// Returns whether the widget is built.
  Future<bool> _revealAtTop(GlobalKey key) async {
    final target = key.currentContext;
    final box = target?.findRenderObject();
    if (!mounted || target == null || box is! RenderBox || !box.attached) {
      return false;
    }
    final viewport = Scrollable.of(target).context.findRenderObject();
    if (viewport is! RenderBox) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < viewport.localToGlobal(Offset.zero).dy) {
      // alignment 1.0 is the top edge in a list that grows upwards.
      await Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    return true;
  }

  /// Sends a quick reply as is; a draft in the composer is kept.
  void _sendFollowUp(String question) {
    final chat = ref.read(aiChatProvider);
    if (_isListening || chat.isSending || chat.pendingMessage != null) return;
    _focusNode.unfocus();
    ref.read(aiChatProvider.notifier).send(question, inputMode: 'text');
  }

  void _useSuggestion(String question) {
    _composer.text = question;
    _composer.selection = TextSelection.collapsed(offset: question.length);
    _draftMode = 'text';
    _focusNode.requestFocus();
    setState(() {});
  }

  /// Drafts "I cooked this" with the suggested amounts of the ingredients
  /// from the fridge. The user corrects what they really used and sends it;
  /// the answer is a consume receipt they confirm before inventory changes.
  void _reportCooked(AiRecipe recipe) {
    if (_isListening || ref.read(aiChatProvider).isSending) return;
    final used = [
      for (final ingredient in recipe.ingredients)
        if (ingredient.inInventory)
          ingredient.quantity == null
              ? ingredient.name
              : '${aiDisplayNumber(ingredient.quantity!)} '
                        '${ingredient.unit ?? ''} ${ingredient.name}'
                    .replaceAll(RegExp(r'\s+'), ' '),
    ];
    _useSuggestion('Tôi đã nấu ${recipe.title}, dùng ${used.join(', ')}');
    context.showToast('Sửa lại lượng bạn đã dùng rồi gửi để trừ kho.');
  }

  /// Lets the user add the recipe's "to buy" ingredients to a shopping list
  /// after reviewing them; the assistant itself never writes the list.
  Future<void> _addToShopping(AiRecipe recipe) async {
    final outcome = await AddRecipeToShoppingSheet.show(
      context,
      recipeTitle: recipe.title,
      ingredients: [
        for (final ingredient in recipe.ingredients)
          if (!ingredient.inInventory)
            RecipeShoppingIngredient(
              name: ingredient.name,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
            ),
      ],
    );
    if (outcome == null || !mounted) return;
    final result = outcome.result;
    final saved = result.added + result.merged;
    final parts = [
      if (saved > 0)
        'Đã thêm $saved món'
            '${result.merged > 0 ? ' (cộng dồn ${result.merged})' : ''}',
      if (result.failedNames.isNotEmpty)
        'Không thêm được: ${result.failedNames.join(', ')}',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join('. ')),
        action: saved == 0
            ? null
            : SnackBarAction(
                label: 'Xem',
                onPressed: () => context.push(
                  AppRouteNames.shoppingListDetailPath(outcome.listId),
                ),
              ),
      ),
    );
  }

  /// Clears the draft (and any dictation) before switching conversations.
  void _resetComposer() {
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
    }
    _speechSession++;
    _focusNode.unfocus();
    _composer.value = TextEditingValue.empty;
    setState(() => _draftMode = 'text');
  }

  void _startNewChat() {
    if (ref.read(aiChatProvider).isSending) return;
    _resetComposer();
    ref.read(aiChatProvider.notifier).startNewSession();
  }

  void _showHistory() {
    final chat = ref.read(aiChatProvider);
    if (chat.isSending) return;
    _focusNode.unfocus();
    BottomSheetHelper.show<void>(
      context,
      title: 'Lịch sử trò chuyện',
      maxHeightFactor: 0.75,
      footer: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            _startNewChat();
          },
          icon: Icon(LucideIcons.squarePen, size: 18.r),
          label: const AppButtonLabel('Cuộc trò chuyện mới'),
        ),
      ),
      child: AiChatHistoryList(
        currentSessionId: chat.sessionId,
        onOpen: (sessionId) {
          Navigator.of(context, rootNavigator: true).pop();
          if (sessionId == ref.read(aiChatProvider).sessionId) return;
          _resetComposer();
          ref.read(aiChatProvider.notifier).openSession(sessionId);
        },
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: BoxConstraints(minWidth: 44.r, minHeight: 44.r),
      icon: Icon(
        icon,
        size: 21.r,
        color: Colors.white.withValues(alpha: onPressed == null ? 0.45 : 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(aiChatProvider, (previous, next) {
      final added = next.messages.length - (previous?.messages.length ?? 0);
      if (added < 2) return;
      final question = next.messages[next.messages.length - 2];
      final answer = next.messages.last;
      if (question.isUser && !answer.isUser) {
        _revealNewTurn(question.id, answer.id);
      }
    });
    final chat = ref.watch(aiChatProvider);
    final historyAsync = ref.watch(aiChatHistoryProvider);
    final history = historyAsync.valueOrNull;
    final byId = <String, AiChatMessage>{};
    for (final message in [...chat.messages, ...?history]) {
      byId[message.id] = message;
    }
    final messages = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        if (a.isUser != b.isUser) return a.isUser ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    final pendingAlreadyVisible =
        chat.pendingRequestId != null &&
        byId.containsKey('${chat.pendingRequestId}-user');
    // The live counter covers a fresh page; the last answer covers the gap
    // while the plan is still loading.
    final quota = ref.watch(aiQuotaProvider).valueOrNull ?? chat.quota;
    final remaining = quota?.remaining;
    final outOfQuota = remaining == 0;
    final canSend =
        !outOfQuota &&
        _composer.text.trim().isNotEmpty &&
        _composer.text.trim().length <= 1000 &&
        !_isListening &&
        !chat.isSending &&
        chat.pendingMessage == null;
    final isEmptyChat = messages.isEmpty && chat.pendingMessage == null;
    final canUseShoppingLists = ref.watch(canUseShoppingListsProvider);
    final followUps =
        !outOfQuota &&
            !chat.isSending &&
            chat.pendingMessage == null &&
            chat.error == null &&
            messages.isNotEmpty
        ? aiFollowUps(messages.last)
        : const <String>[];

    return SubpageLayout(
      header: AppHeader(
        title: 'Trợ lý FOORA',
        onBack: () => context.pop(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerAction(
              icon: LucideIcons.history,
              tooltip: 'Lịch sử trò chuyện',
              onPressed: chat.isSending ? null : _showHistory,
            ),
            _headerAction(
              icon: LucideIcons.squarePen,
              tooltip: 'Cuộc trò chuyện mới',
              onPressed: chat.isSending || isEmptyChat ? null : _startNewChat,
            ),
          ],
        ),
      ),
      // The composer sits in the body, not in bottomNavigationBar, so the
      // resizing Scaffold keeps it above the on-screen keyboard.
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child:
                  historyAsync.isLoading &&
                      chat.messages.isEmpty &&
                      chat.pendingMessage == null
                  ? const LoadingWidget(message: 'Đang tải lịch sử chat…')
                  : messages.isEmpty && chat.pendingMessage == null
                  ? _buildWelcome(historyAsync.hasError)
                  : ListView(
                      controller: _scroll,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 20.h,
                      ),
                      children: [
                        if (historyAsync.hasError)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: TextButton(
                              onPressed: () =>
                                  ref.invalidate(aiChatHistoryProvider),
                              child: const AppButtonLabel(
                                'Không tải được lịch sử chat · Thử lại',
                              ),
                            ),
                          ),
                        if (chat.error != null) _buildError(chat.error!),
                        if (chat.isSending &&
                            !byId.containsKey(
                              '${chat.pendingRequestId}-assistant',
                            ))
                          const AiThinkingIndicator(),
                        if (chat.pendingMessage != null &&
                            !pendingAlreadyVisible) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: EdgeInsets.only(bottom: 14.h),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(18.r),
                              ),
                              child: Text(
                                chat.pendingMessage!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 15.sp,
                                  color: AppColors.surfaceContainerLowest,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (followUps.isNotEmpty)
                          AiFollowUpChips(
                            questions: followUps,
                            onSelected: _sendFollowUp,
                          ),
                        ...messages.reversed.map(
                          (message) => ChatBubble(
                            key: message.id == _revealQuestionId
                                ? _questionKey
                                : message.id == _revealAnswerId
                                ? _answerKey
                                : ValueKey(message.id),
                            message: message,
                            onCooked: _reportCooked,
                            onAddToShopping: canUseShoppingLists
                                ? _addToShopping
                                : null,
                            onReviewActions: message.actionStatus == 'proposed'
                                ? () async {
                                    await showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) =>
                                          AiActionReviewSheet(message: message),
                                    );
                                    ref.invalidate(aiChatHistoryProvider);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: AppColors.slate100)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isListening)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Text(
                          'Đang nghe tiếng Việt… Bấm micro để dừng. Bạn có thể sửa lời nói trước khi gửi.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Semantics(
                          label: _isListening
                              ? 'Dừng ghi âm'
                              : 'Nhập câu hỏi bằng giọng nói',
                          button: true,
                          child: IconButton(
                            onPressed: chat.isSending || outOfQuota
                                ? null
                                : _toggleSpeech,
                            tooltip: _isListening ? 'Dừng nghe' : 'Nói câu hỏi',
                            constraints: BoxConstraints(
                              minWidth: 48.r,
                              minHeight: 48.r,
                            ),
                            icon: Icon(
                              _isListening
                                  ? LucideIcons.square
                                  : LucideIcons.mic,
                              color: _isListening
                                  ? AppColors.red700
                                  : AppColors.primary,
                              size: 22.r,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextField(
                            controller: _composer,
                            focusNode: _focusNode,
                            readOnly:
                                _isListening || chat.isSending || outOfQuota,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 1000,
                            textInputAction: TextInputAction.send,
                            textCapitalization: TextCapitalization.sentences,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 15.sp,
                            ),
                            decoration: InputDecoration(
                              hintText: outOfQuota
                                  ? 'Đã hết lượt hỏi hôm nay'
                                  : 'Hỏi về thực phẩm trong tủ…',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 15.w,
                                vertical: 13.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide(
                                  color: AppColors.slate200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide(
                                  color: AppColors.slate200,
                                ),
                              ),
                            ),
                            onChanged: (_) {
                              if (chat.pendingMessage != null &&
                                  !chat.isSending) {
                                ref
                                    .read(aiChatProvider.notifier)
                                    .discardPending();
                              }
                              setState(() {});
                            },
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton.filled(
                          onPressed: canSend ? _send : null,
                          tooltip: 'Gửi câu hỏi',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.slate200,
                            minimumSize: Size(48.r, 48.r),
                          ),
                          icon: Icon(LucideIcons.arrowUp, size: 22.r),
                        ),
                      ],
                    ),
                    if (outOfQuota)
                      _buildOutOfQuota()
                    else if (remaining != null)
                      Padding(
                        padding: EdgeInsets.only(top: 6.h),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Còn $remaining lượt hôm nay',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12.sp,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(bool historyFailed) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      children: [
        if (historyFailed)
          Padding(
            padding: EdgeInsets.only(bottom: 20.h),
            child: TextButton(
              onPressed: () => ref.invalidate(aiChatHistoryProvider),
              child: const AppButtonLabel(
                'Không tải được lịch sử chat · Thử lại',
              ),
            ),
          ),
        Icon(LucideIcons.sparkles, size: 27.r, color: AppColors.primary),
        SizedBox(height: 16.h),
        Text(
          'Hỏi về tủ lạnh của bạn',
          style: AppTextStyles.headlineSmall.copyWith(
            fontSize: 24.sp,
            color: AppColors.slate800,
          ),
        ),
        SizedBox(height: 9.h),
        Text(
          'Gõ hoặc bấm micro để hỏi về số lượng và hạn dùng. Lời nói sẽ hiện trong ô chat để bạn kiểm tra trước khi gửi.',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 15.sp,
            height: 1.5,
            color: AppColors.slate600,
          ),
        ),
        SizedBox(height: 28.h),
        for (final question in aiWelcomeSuggestions(
          ref.watch(activeHouseholdInventoryStreamProvider).valueOrNull ??
              const [],
          DateTime.now(),
        )) ...[_suggestion(question), SizedBox(height: 10.h)],
        SizedBox(height: 28.h),
        Text(
          'Khi bạn gửi câu hỏi, nội dung chat và dữ liệu kho liên quan được chuyển đến dịch vụ AI.',
          style: AppTextStyles.caption.copyWith(
            fontSize: 12.sp,
            color: AppColors.slate600,
          ),
        ),
      ],
    );
  }

  Widget _suggestion(String question) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _useSuggestion(question),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate200),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            question,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 15.sp,
              color: AppColors.slate800,
            ),
          ),
        ),
      ),
    );
  }

  /// Replaces the remaining-count line once today's questions are used up.
  Widget _buildOutOfQuota() {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 14.r, color: AppColors.slate500),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'Bạn đã dùng hết lượt hỏi AI hôm nay',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12.sp,
                color: AppColors.slate600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRouteNames.membership),
            child: const AppButtonLabel('Nâng cấp gói'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.red50,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.red900),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 16.w,
              children: [
                TextButton(
                  onPressed: () => ref.read(aiChatProvider.notifier).retry(),
                  child: const AppButtonLabel('Thử lại'),
                ),
                TextButton(
                  onPressed: _editPending,
                  child: const AppButtonLabel('Sửa câu hỏi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
