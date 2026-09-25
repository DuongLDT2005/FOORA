import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';

/// Notice inbox. Layout stays on the existing Stitch-mapped shell:
/// [AppHeader.notifications], [SubpageLayout], and [NotificationTile].
/// Stitch MCP had no API key in this environment, so no extra screen was added.
class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  @override
  Widget build(BuildContext context) {
    final query = GoRouterState.of(context).uri.queryParameters;
    final requestedItemId = query['inventoryItemId'];
    final requestedHouseholdId = query['householdId'];

    final userAsync = ref.watch(currentNotificationUserIdProvider);
    final page = userAsync.when(
      loading: () =>
          _shell(body: const LoadingWidget(message: 'Đang tải thông báo...')),
      error: (_, _) => _shell(
        body: ErrorStateWidget(
          onRetry: () => ref.invalidate(currentNotificationUserIdProvider),
        ),
      ),
      data: (userId) {
        if (userId == null || userId.isEmpty) {
          return _shell(
            body: const Center(
              child: Text('Vui lòng đăng nhập để xem thông báo.'),
            ),
          );
        }
        return _buildInbox(userId);
      },
    );
    if (requestedItemId == null || requestedItemId.isEmpty) {
      return page;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        _PushItemOpener(
          itemId: requestedItemId,
          householdId: requestedHouseholdId,
        ),
      ],
    );
  }

  Widget _buildInbox(String userId) {
    final notificationsAsync = ref.watch(
      userNotificationsStreamProvider(userId),
    );

    return notificationsAsync.when(
      loading: () =>
          _shell(body: const LoadingWidget(message: 'Đang tải thông báo...')),
      error: (_, _) => _shell(
        body: ErrorStateWidget(
          onRetry: () =>
              ref.invalidate(userNotificationsStreamProvider(userId)),
        ),
      ),
      data: (notifications) {
        final unreadCount = notifications.where((item) => !item.isRead).length;
        return _shell(
          unreadCount: unreadCount,
          onMarkAllAsRead: unreadCount > 0
              ? () => _markAllAsRead(userId)
              : null,
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
                      onTap: () => _onTileTap(userId, item),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _shell({
    required Widget body,
    int unreadCount = 0,
    VoidCallback? onMarkAllAsRead,
  }) {
    return SubpageLayout(
      header: AppHeader.notifications(
        unreadCount: unreadCount,
        onBack: () => context.pop(),
        onMarkAllAsRead: onMarkAllAsRead,
      ),
      body: body,
    );
  }

  Future<void> _markAllAsRead(String userId) async {
    await ref.read(notificationNotifierProvider.notifier).markAllAsRead(userId);
    if (!mounted) {
      return;
    }
    ToastHelper.show(context, 'Đã đánh dấu tất cả là đã đọc.');
  }

  Future<void> _onTileTap(String userId, AppNotification item) async {
    if (!item.isRead) {
      await ref
          .read(notificationNotifierProvider.notifier)
          .markAsRead(userId, item.id);
    }
    if (!mounted) {
      return;
    }
    final itemId = item.inventoryItemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }
    final loaded =
        ref.read(activeHouseholdInventoryStreamProvider).valueOrNull ??
        const <InventoryItem>[];
    final match = _findLoadedItem(
      items: loaded,
      itemId: itemId,
      householdId: item.householdId,
      activeHouseholdId: ref.read(currentUserProvider)?.activeHouseholdId,
    );
    if (match != null && mounted) {
      context.push(AppRouteNames.itemForm, extra: match);
    }
  }
}

class _PushItemOpener extends ConsumerStatefulWidget {
  final String itemId;
  final String? householdId;

  const _PushItemOpener({required this.itemId, this.householdId});

  @override
  ConsumerState<_PushItemOpener> createState() => _PushItemOpenerState();
}

class _PushItemOpenerState extends ConsumerState<_PushItemOpener> {
  var _opened = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeHouseholdInventoryStreamProvider, (_, next) {
      if (_opened) {
        return;
      }
      final match = _findLoadedItem(
        items: next.valueOrNull ?? const [],
        itemId: widget.itemId,
        householdId: widget.householdId,
        activeHouseholdId: ref.read(currentUserProvider)?.activeHouseholdId,
      );
      if (match == null) {
        return;
      }
      _opened = true;
      context.push(AppRouteNames.itemForm, extra: match);
    });
    return const SizedBox.shrink();
  }
}

InventoryItem? _findLoadedItem({
  required List<InventoryItem> items,
  required String itemId,
  required String? householdId,
  required String? activeHouseholdId,
}) {
  if (householdId != null &&
      householdId.isNotEmpty &&
      activeHouseholdId != householdId) {
    return null;
  }
  for (final item in items) {
    if (item.id == itemId) {
      return item;
    }
  }
  return null;
}
