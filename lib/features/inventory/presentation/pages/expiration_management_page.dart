import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/expiration_list_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/expiration_group_header.dart';
import '../widgets/expiration_item_card.dart';
import '../widgets/expiration_stats_board.dart';
import '../../domain/entities/inventory_item.dart';

class ExpirationManagementPage extends ConsumerWidget {
  const ExpirationManagementPage({super.key});

  void _onSwipeDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;
    if (householdId == null) return;
    try {
      final updatedItem = item.copyWith(
        status: InventoryItemStatus.discarded,
        updatedAt: DateTime.now(),
      );
      await ref
          .read(updateInventoryItemUseCaseProvider)
          .call(updatedItem, householdId: householdId);
    } catch (e) {
      if (context.mounted) {
        ToastHelper.show(context, 'Lỗi khi xoá thực phẩm: $e', isError: true);
      }
    }
  }

  void _onDeleteAllExpired(
    BuildContext context,
    WidgetRef ref,
    List<InventoryItem> expiredItems,
  ) async {
    if (expiredItems.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final householdId = user?.activeHouseholdId;
    if (householdId == null) return;

    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa tất cả thực phẩm đã quá hạn?',
      message:
          'Thao tác này sẽ chuyển ${expiredItems.length} món sang trạng thái Đã hỏng. Bạn có chắc chắn?',
      confirmText: 'Xóa tất cả',
    );

    if (confirmed == true && context.mounted) {
      try {
        final itemIds = expiredItems.map((e) => e.id).toList();
        await ref
            .read(batchUpdateInventoryStatusUseCaseProvider)
            .call(
              itemIds,
              InventoryItemStatus.discarded,
              householdId: householdId,
            );
        if (context.mounted) {
          ToastHelper.show(
            context,
            'Đã xóa ${expiredItems.length} thực phẩm quá hạn',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.show(context, 'Lỗi khi xóa hàng loạt: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expirationListNotifierProvider);
    final categories = ref.watch(foodCategoriesProvider).valueOrNull ?? [];
    final locations = ref.watch(storageLocationsProvider).valueOrNull ?? [];

    String getCategoryName(String id) {
      final match = categories.where((c) => c.id == id);
      return match.isNotEmpty ? match.first.name : 'Chưa phân loại';
    }

    String getLocationName(String id) {
      final match = locations.where((l) => l.id == id);
      return match.isNotEmpty ? match.first.name : 'Chưa phân loại';
    }

    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: state.isLoading && state.expiredItems.isEmpty && state.safeItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Quản lý hạn dùng',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate800,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: AppColors.slate200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.chevron_left, size: 16.sp, color: AppColors.slate700),
                                SizedBox(width: 4.w),
                                Text(
                                  'Tất cả kho',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                  // Stats Board
                  ExpirationStatsBoard(
                    urgentCount: state.urgentCount,
                    spoiledCount: state.spoiledCount,
                  ),

                  SizedBox(height: 24.h),

                  // Sort Header
                  Container(
                    padding: EdgeInsets.only(bottom: 4.h),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.slate100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DANH SÁCH ƯU TIÊN',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => ref.read(expirationListNotifierProvider.notifier).setSortType(ExpirationSortType.expirationDate),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: state.sortType == ExpirationSortType.expirationDate ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6.r),
                                    boxShadow: state.sortType == ExpirationSortType.expirationDate
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Hạn dùng',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      color: state.sortType == ExpirationSortType.expirationDate ? AppColors.primary : AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => ref.read(expirationListNotifierProvider.notifier).setSortType(ExpirationSortType.quantity),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: state.sortType == ExpirationSortType.quantity ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6.r),
                                    boxShadow: state.sortType == ExpirationSortType.quantity
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Lượng còn',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      color: state.sortType == ExpirationSortType.quantity ? AppColors.primary : AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Expired Group
                  if (state.expiredItems.isNotEmpty) ...[
                    ExpirationGroupHeader(
                      title: 'Đã quá hạn',
                      color: AppColors.red600,
                      animateDot: true,
                      trailing: GestureDetector(
                        onTap: () => _onDeleteAllExpired(
                          context,
                          ref,
                          state.expiredItems,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red50,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'Xóa tất cả',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...state.expiredItems.map(
                      (item) => ExpirationItemCard(
                        item: item,
                        categoryName: getCategoryName(item.categoryId),
                        storageLocationName: getLocationName(
                          item.storageLocationId,
                        ),
                        groupType: ExpirationGroupType.expired,
                        onSwipeDelete: () => _onSwipeDelete(context, ref, item),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Today Group
                  if (state.todayItems.isNotEmpty) ...[
                    const ExpirationGroupHeader(
                      title: 'Hết hạn hôm nay',
                      color: AppColors.amber600,
                      animateDot: true,
                    ),
                    ...state.todayItems.map(
                      (item) => ExpirationItemCard(
                        item: item,
                        categoryName: getCategoryName(item.categoryId),
                        storageLocationName: getLocationName(
                          item.storageLocationId,
                        ),
                        groupType: ExpirationGroupType.today,
                        onSwipeDelete: () => _onSwipeDelete(context, ref, item),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Tomorrow Group
                  if (state.tomorrowItems.isNotEmpty) ...[
                    const ExpirationGroupHeader(
                      title: 'Hết hạn ngày mai',
                      color: AppColors.amber500,
                    ),
                    ...state.tomorrowItems.map(
                      (item) => ExpirationItemCard(
                        item: item,
                        categoryName: getCategoryName(item.categoryId),
                        storageLocationName: getLocationName(
                          item.storageLocationId,
                        ),
                        groupType: ExpirationGroupType.tomorrow,
                        onSwipeDelete: () => _onSwipeDelete(context, ref, item),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Upcoming Group
                  if (state.upcomingItems.isNotEmpty) ...[
                    const ExpirationGroupHeader(
                      title: 'Sắp hết hạn (2-3 ngày tới)',
                      color: AppColors.amber500,
                    ),
                    ...state.upcomingItems.map(
                      (item) => ExpirationItemCard(
                        item: item,
                        categoryName: getCategoryName(item.categoryId),
                        storageLocationName: getLocationName(
                          item.storageLocationId,
                        ),
                        groupType: ExpirationGroupType.upcoming,
                        onSwipeDelete: () => _onSwipeDelete(context, ref, item),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Safe Group
                  if (state.safeItems.isNotEmpty) ...[
                    const ExpirationGroupHeader(
                      title: 'Còn hạn lâu dài',
                      color: AppColors.emerald500,
                    ),
                    ...state.safeItems.map(
                      (item) => ExpirationItemCard(
                        item: item,
                        categoryName: getCategoryName(item.categoryId),
                        storageLocationName: getLocationName(
                          item.storageLocationId,
                        ),
                        groupType: ExpirationGroupType.safe,
                        onSwipeDelete: () => _onSwipeDelete(context, ref, item),
                      ),
                    ),
                  ],

                  SizedBox(height: 60.h), // padding for bottom navigation
                ],
              ),
            ),
      ),
    );
  }
}
