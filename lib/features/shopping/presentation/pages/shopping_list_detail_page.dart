import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/add_edit_shopping_item_sheet.dart';
import '../widgets/batch_import_inventory_sheet.dart';
import '../widgets/create_edit_shopping_list_sheet.dart';
import '../widgets/shopping_item_tile.dart';

class ShoppingListDetailPage extends ConsumerWidget {
  final String listId;
  final ShoppingList? initialList;

  const ShoppingListDetailPage({
    super.key,
    required this.listId,
    this.initialList,
  });

  Future<void> _deleteList(BuildContext context, WidgetRef ref, String listName) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa danh sách mua sắm',
      message: 'Bạn có chắc chắn muốn xóa danh sách "$listName"?',
    );

    if (confirmed == true) {
      try {
        await ref.read(shoppingControllerProvider.notifier).deleteShoppingList(listId);
        if (context.mounted) {
          ToastHelper.show(context, 'Đã xóa danh sách mua sắm');
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.show(context, 'Lỗi khi xóa: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, ShoppingItem item) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa món cần mua',
      message: 'Bạn có muốn xóa "${item.name}" khỏi danh sách?',
    );

    if (confirmed == true) {
      try {
        await ref.read(shoppingControllerProvider.notifier).deleteShoppingItem(listId, item.id);
      } catch (e) {
        if (context.mounted) {
          ToastHelper.show(context, 'Lỗi khi xóa món: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(shoppingListStreamProvider(listId));
    final itemsAsync = ref.watch(shoppingItemsStreamProvider(listId));

    final currentList = listAsync.valueOrNull ?? initialList;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          currentList?.name ?? 'Danh sách mua sắm',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamilyHeadline,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (currentList != null)
            PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 20.r,
                color: AppColors.slate600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              onSelected: (value) {
                if (value == 'rename') {
                  CreateEditShoppingListSheet.show(context, listToEdit: currentList);
                } else if (value == 'delete') {
                  _deleteList(context, ref, currentList.name);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(LucideIcons.pencil, size: 16, color: AppColors.slate600),
                      SizedBox(width: 8),
                      Text('Đổi tên danh sách'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(LucideIcons.trash2, size: 16, color: AppColors.red500),
                      SizedBox(width: 8),
                      Text('Xóa danh sách', style: TextStyle(color: AppColors.red500)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const LoadingWidget(message: 'Đang tải các món cần mua...'),
        error: (err, stack) => ErrorStateWidget(
          message: 'Không thể tải danh sách món: $err',
          onRetry: () => ref.invalidate(shoppingItemsStreamProvider(listId)),
        ),
        data: (items) {
          final toBuyItems = items.where((i) => !i.isPurchased).toList();
          final purchasedItems = items.where((i) => i.isPurchased).toList();

          final totalCount = items.length;
          final purchasedCount = purchasedItems.length;
          final progressRatio = totalCount > 0 ? (purchasedCount / totalCount).clamp(0.0, 1.0) : 0.0;
          final candidateForInventory =
              purchasedItems.where((i) => !i.isAddedToInventory).toList();

          return Column(
            children: [
              // Progress Banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tiến độ mua sắm',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate700,
                          ),
                        ),
                        Text(
                          '$purchasedCount/$totalCount món (${(progressRatio * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: progressRatio == 1.0 && totalCount > 0
                                ? AppColors.primary
                                : AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 8.h,
                        backgroundColor: AppColors.slate100,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.slate100),

              // Items List or Empty
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EmptyStateWidget(
                                title: 'Chưa có món nào',
                                subtitle:
                                    'Hãy thêm những món thực phẩm bạn cần mua cho gia đình.',
                              ),
                              SizedBox(height: 16.h),
                              ElevatedButton.icon(
                                onPressed: () => AddEditShoppingItemSheet.show(
                                  context,
                                  listId: listId,
                                ),
                                icon: const Icon(LucideIcons.plus),
                                label: const Text('Thêm món đầu tiên'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                        children: [
                          // Section: Cần mua
                          if (toBuyItems.isNotEmpty) ...[
                            Row(
                              children: [
                                Text(
                                  'Cần mua',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate200,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    '${toBuyItems.length}',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            ...toBuyItems.map(
                              (item) => ShoppingItemTile(
                                item: item,
                                onTogglePurchased: (_) {
                                  ref
                                      .read(shoppingControllerProvider.notifier)
                                      .togglePurchased(listId, item);
                                },
                                onEdit: () => AddEditShoppingItemSheet.show(
                                  context,
                                  listId: listId,
                                  itemToEdit: item,
                                ),
                                onDelete: () => _deleteItem(context, ref, item),
                              ),
                            ),
                            SizedBox(height: 16.h),
                          ],

                          // Section: Đã mua
                          if (purchasedItems.isNotEmpty) ...[
                            Row(
                              children: [
                                Text(
                                  'Đã mua',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    '${purchasedItems.length}',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            ...purchasedItems.map(
                              (item) => ShoppingItemTile(
                                item: item,
                                onTogglePurchased: (_) {
                                  ref
                                      .read(shoppingControllerProvider.notifier)
                                      .togglePurchased(listId, item);
                                },
                                onEdit: () => AddEditShoppingItemSheet.show(
                                  context,
                                  listId: listId,
                                  itemToEdit: item,
                                ),
                                onDelete: () => _deleteItem(context, ref, item),
                              ),
                            ),
                          ],
                          SizedBox(height: 80.h), // space for bottom bar
                        ],
                      ),
              ),

              // Bottom Actions Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Add Item Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => AddEditShoppingItemSheet.show(
                            context,
                            listId: listId,
                          ),
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: const Text('Thêm món', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (candidateForInventory.isNotEmpty) ...[
                        SizedBox(width: 12.w),
                        // Add to Inventory Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => BatchImportInventorySheet.show(
                              context,
                              listId: listId,
                              candidateItems: candidateForInventory,
                            ),
                            icon: const Icon(LucideIcons.packagePlus, size: 18),
                            label: Text(
                              'Nhập kho (${candidateForInventory.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
