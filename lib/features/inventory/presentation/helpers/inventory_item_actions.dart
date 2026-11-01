import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_provider.dart';

/// Card actions shared by the inventory and expiry management screens.
class InventoryItemActions {
  InventoryItemActions._();

  /// Opens the edit form, or explains the lock for a locked item.
  static void open(BuildContext context, InventoryItem item) {
    if (item.isLocked) {
      _showLockedDialog(context);
      return;
    }
    context.push(AppRouteNames.itemForm, extra: item);
  }

  /// Locked items exceed the Free food limit: they cannot be edited, only
  /// used up or thrown away (swipe), or unlocked by renewing Premium.
  static Future<void> _showLockedDialog(BuildContext context) async {
    final upgrade = await DialogHelper.showConfirmDialog(
      context,
      title: 'Món đang bị khóa',
      message:
          'Tủ lạnh đang có nhiều món hơn giới hạn của gói Free nên món này '
          'tạm thời bị khóa. Chủ gia đình gia hạn Premium để mở khóa, hoặc '
          'vuốt sang trái để đánh dấu đã dùng / vứt bỏ.',
      confirmText: 'Xem gói Premium',
      cancelText: 'Đóng',
      icon: LucideIcons.lock,
    );
    if (upgrade == true && context.mounted) {
      context.push(AppRouteNames.membership);
    }
  }

  /// Asks whether the item was used up or thrown away, then updates it.
  /// Returns `true` when the item left the active list.
  static Future<bool> confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    final status = await DialogHelper.showChoiceDialog<InventoryItemStatus>(
      context,
      title: 'Cập nhật trạng thái',
      message: 'Bạn đã sử dụng hết hay vứt bỏ thực phẩm này?',
      confirmText: 'Đã dùng',
      confirmValue: InventoryItemStatus.consumed,
      confirmIcon: LucideIcons.utensils,
      secondaryText: 'Vứt bỏ',
      secondaryValue: InventoryItemStatus.discarded,
      secondaryIcon: LucideIcons.trash2,
      cancelText: 'Giữ lại trong tủ',
      icon: LucideIcons.salad,
    );
    if (status == null) return false;
    try {
      await ref.read(inventoryStatusControllerProvider).changeStatus([
        itemId,
      ], status);
      return true;
    } on Failure catch (failure) {
      if (context.mounted) {
        ToastHelper.show(context, failure.message, isError: true);
      }
      return false;
    }
  }
}
