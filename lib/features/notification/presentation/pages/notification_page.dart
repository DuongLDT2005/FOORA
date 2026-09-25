import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId =
        ref.watch(currentNotificationUserIdProvider).valueOrNull ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppHeader(title: 'Thông báo', onBack: () => context.pop()),
        body: const Center(child: Text('Vui lòng đăng nhập để xem thông báo.')),
      );
    }

    final notificationsAsync = ref.watch(
      userNotificationsStreamProvider(userId),
    );

    return notificationsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: LoadingWidget(message: 'Đang tải thông báo...')),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppHeader(title: 'Thông báo', onBack: () => context.pop()),
        body: Center(
          child: Text(
            'Lỗi khi tải thông báo: $err',
            style: const TextStyle(color: AppColors.red600),
          ),
        ),
      ),
      data: (notifications) {
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return SubpageLayout(
          header: AppHeader.notifications(
            unreadCount: unreadCount,
            onBack: () => context.pop(),
            onMarkAllAsRead: unreadCount > 0
                ? () async {
                    await ref
                        .read(notificationNotifierProvider.notifier)
                        .markAllAsRead(userId);
                    if (context.mounted) {
                      ToastHelper.show(
                        context,
                        'Đã đánh dấu tất cả là đã đọc.',
                      );
                    }
                  }
                : null,
          ),
          body: notifications.isEmpty
              ? const Center(
                  child: EmptyStateWidget(
                    icon: LucideIcons.bellOff,
                    title: 'Chưa có thông báo nào',
                    subtitle:
                        'Khi thực phẩm sắp hết hạn hoặc có tin tức mới từ gia đình, bạn sẽ nhận được thông báo tại đây.',
                  ),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return NotificationTile(
                      notification: item,
                      onTap: () async {
                        if (!item.isRead) {
                          await ref
                              .read(notificationNotifierProvider.notifier)
                              .markAsRead(userId, item.id);
                        }
                        if (item.inventoryItemId != null && context.mounted) {
                          context.go(AppRouteNames.inventory);
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
