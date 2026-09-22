import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/inventory_list_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/category_filter_list.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_search_bar.dart';
import '../widgets/inventory_stats_banner.dart';
import '../widgets/location_filter_tabs.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch state
    final filteredItems = ref.watch(
      inventoryListNotifierProvider.select((s) => s.filteredItems),
    );
    final expiringSoonCount = ref.watch(
      inventoryListNotifierProvider.select((s) => s.expiringSoonCount),
    );
    final expiredCount = ref.watch(
      inventoryListNotifierProvider.select((s) => s.expiredCount),
    );
    final totalWarning = expiringSoonCount + expiredCount;

    final isListLoading = ref.watch(activeHouseholdInventoryStreamProvider).isLoading;
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kho thực phẩm',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                  // Manage expiry button
                  GestureDetector(
                    onTap: () {
                      context.pushNamed('expirationManagement');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.red100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Quản lý hạn dùng',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red700,
                            ),
                          ),
                          if (totalWarning > 0) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.red600,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                totalWarning.toString(),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search and Location Filters
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const InventorySearchBar(),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const LocationFilterTabs(),
            ),
            SizedBox(height: 16.h),
            
            // Category Filter
            const CategoryFilterList(),
            SizedBox(height: 16.h),

            // Scrollable Content
            Expanded(
              child: isListLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(activeHouseholdInventoryStreamProvider);
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Banner
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: const InventoryStatsBanner(),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                          
                          // List
                          if (filteredItems.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'Không tìm thấy thực phẩm nào.',
                                  style: TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = filteredItems[index];
                                    final categories = categoriesAsync.valueOrNull ?? [];
                                    final category = categories.where((c) => c.id == item.categoryId).firstOrNull;
                                    
                                    return InventoryItemCard(
                                      id: item.id,
                                      name: item.name,
                                      quantity: item.quantity.toString(),
                                      unit: item.unit,
                                      percentageRemaining: item.remainingPercentage,
                                      imageUrl: item.photoUrl,
                                      category: category,
                                      storageLocationId: item.storageLocationId,
                                      expirationDate: item.expirationDate,
                                      onDelete: () async {
                                        // Show dialog to consume or discard
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Xóa thực phẩm', style: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.bold)),
                                            content: const Text('Bạn đã sử dụng hết hay vứt bỏ thực phẩm này?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, 'cancel'),
                                                child: const Text('Hủy', style: TextStyle(color: AppColors.slate500)),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, 'discarded'),
                                                child: const Text('Vứt bỏ', style: TextStyle(color: AppColors.red600)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx, 'consumed'),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                                child: const Text('Đã dùng', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (result == 'consumed' || result == 'discarded') {
                                          final user = ref.read(currentUserProvider);
                                          if (user?.activeHouseholdId != null) {
                                            final newStatus = result == 'consumed'
                                                ? InventoryItemStatus.consumed
                                                : InventoryItemStatus.discarded;
                                            final updatedItem = item.copyWith(
                                              status: newStatus,
                                              updatedAt: DateTime.now(),
                                            );
                                            ref.read(updateInventoryItemUseCaseProvider)(
                                              updatedItem, 
                                              householdId: user!.activeHouseholdId!,
                                            );
                                          }
                                        }
                                      },
                                      onTap: () {
                                        context.pushNamed(
                                          'itemForm',
                                          extra: item,
                                        );
                                      },
                                    );
                                  },
                                  childCount: filteredItems.length,
                                ),
                              ),
                            ),
                            
                          // Bottom padding for FAB
                          SliverToBoxAdapter(child: SizedBox(height: 100.h)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
