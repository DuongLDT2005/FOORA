import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/ai_chat_session.dart';
import '../providers/ai_provider.dart';
import '../../../../shared/widgets/app_button.dart';

/// Saved conversations shown in the history sheet of the chat page.
class AiChatHistoryList extends ConsumerWidget {
  const AiChatHistoryList({
    super.key,
    required this.currentSessionId,
    required this.onOpen,
  });

  final String currentSessionId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(aiChatSessionsProvider);
    return sessionsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => _message(
        'Không tải được lịch sử trò chuyện.',
        action: TextButton(
          onPressed: () => ref.invalidate(aiChatSessionsProvider),
          child: const AppButtonLabel('Thử lại'),
        ),
      ),
      data: (sessions) => sessions.isEmpty
          ? _message('Chưa có cuộc trò chuyện nào được lưu.')
          : Column(
              children: [
                for (final session in sessions)
                  _SessionTile(
                    session: session,
                    isCurrent: session.id == currentSessionId,
                    onTap: () => onOpen(session.id),
                  ),
              ],
            ),
    );
  }

  Widget _message(String text, {Widget? action}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h),
      child: Column(
        children: [
          Icon(
            LucideIcons.messagesSquare,
            size: 28.r,
            color: AppColors.slate400,
          ),
          SizedBox(height: 10.h),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate600),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.isCurrent,
    required this.onTap,
  });

  final AiChatSession session;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: isCurrent
            ? AppColors.emerald50
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: isCurrent ? AppColors.primary : AppColors.slate200,
              ),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                      if (session.lastMessage.isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Text(
                          session.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.slate600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                isCurrent
                    ? Text(
                        'Đang mở',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        aiSessionTimeLabel(session.updatedAt, DateTime.now()),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.slate500,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `14:05` today, `Hôm qua` yesterday, otherwise `dd/MM` (`dd/MM/yy` for
/// earlier years).
String aiSessionTimeLabel(DateTime time, DateTime now) {
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return DateFormat('HH:mm').format(time);
  if (days == 1) return 'Hôm qua';
  return DateFormat(time.year == now.year ? 'dd/MM' : 'dd/MM/yy').format(time);
}
