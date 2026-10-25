import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ai_action_review_sheet.dart';

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

  @override
  void dispose() {
    _speech.cancel();
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
      _beforeSpeech = _composer.text.trimRight();
      _draftMode = 'voice';
      await _speech.listen(
        onResult: _onSpeechResult,
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

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    final prefix = _beforeSpeech.isEmpty ? '' : '$_beforeSpeech ';
    _composer.value = TextEditingValue(
      text: '$prefix$words',
      selection: TextSelection.collapsed(offset: prefix.length + words.length),
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

  void _useSuggestion(String question) {
    _composer.text = question;
    _composer.selection = TextSelection.collapsed(offset: question.length);
    _draftMode = 'text';
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
    final canSend =
        _composer.text.trim().isNotEmpty &&
        _composer.text.trim().length <= 1000 &&
        !_isListening &&
        !chat.isSending &&
        chat.pendingMessage == null;

    return SubpageLayout(
      header: AppHeader(
        title: 'Trợ lý FOORA',
        onBack: () => context.pop(),
        trailing: chat.quota == null
            ? null
            : Text(
                chat.quota!.remaining == null
                    ? 'Không giới hạn'
                    : 'Còn ${chat.quota!.remaining} lượt',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.surfaceContainerLowest,
                  fontSize: 12.sp,
                ),
              ),
      ),
      body: GestureDetector(
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
                reverse: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                children: [
                  if (historyAsync.hasError)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: TextButton(
                        onPressed: () => ref.invalidate(aiChatHistoryProvider),
                        child: const Text(
                          'Không tải được lịch sử chat · Thử lại',
                        ),
                      ),
                    ),
                  if (chat.error != null) _buildError(chat.error!),
                  if (chat.isSending &&
                      !byId.containsKey('${chat.pendingRequestId}-assistant'))
                    _buildThinking(),
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
                  ...messages.reversed.map(
                    (message) => ChatBubble(
                      message: message,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: AppColors.surfaceContainerLowest,
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
                      onPressed: chat.isSending ? null : _toggleSpeech,
                      tooltip: _isListening ? 'Dừng nghe' : 'Nói câu hỏi',
                      constraints: BoxConstraints(
                        minWidth: 48.r,
                        minHeight: 48.r,
                      ),
                      icon: Icon(
                        _isListening ? LucideIcons.square : LucideIcons.mic,
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
                      readOnly: _isListening || chat.isSending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 15.sp),
                      decoration: InputDecoration(
                        hintText: 'Hỏi về thực phẩm trong tủ…',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 15.w,
                          vertical: 13.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: AppColors.slate200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: AppColors.slate200),
                        ),
                      ),
                      onChanged: (_) {
                        if (chat.pendingMessage != null && !chat.isSending) {
                          ref.read(aiChatProvider.notifier).discardPending();
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
            ],
          ),
        ),
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
              child: const Text('Không tải được lịch sử chat · Thử lại'),
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
        _suggestion('Trong tủ còn thực phẩm nào sắp hết hạn?'),
        SizedBox(height: 10.h),
        _suggestion('Tôi nên dùng thực phẩm nào trước?'),
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

  Widget _buildThinking() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16.r,
              height: 16.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'FOORA đang trả lời…',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
              ),
            ),
          ],
        ),
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
                  child: const Text('Thử lại'),
                ),
                TextButton(
                  onPressed: _editPending,
                  child: const Text('Sửa câu hỏi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
