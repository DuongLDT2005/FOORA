import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/home_horizontal_item_card.dart';
import '../widgets/home_recent_item_card.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_stats_board.dart';
import '../widgets/home_vertical_item_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = user?.fullName ?? '';
    final displayName = fullName.isEmpty ? 'Khách' : fullName;
    final firstName = displayName.split(' ').last;

    final dashboardAsync = ref.watch(homeDashboardStreamProvider);
    final dashboardData = dashboardAsync.valueOrNull;

    if (dashboardData == null) {
      return Container(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: dashboardAsync.hasError
              ? ErrorStateWidget(
                  message: 'Không thể tải dữ liệu trang chủ.',
                  onRetry: () => ref.invalidate(homeDashboardStreamProvider),
                )
              : const LoadingWidget(message: 'Đang tải tủ lạnh của bạn...'),
        ),
      );
    }

    final totalCount = dashboardData.totalCount;
    final expiringSoonCount = dashboardData.expiringSoonCount;
    final expiredCount = dashboardData.expiredCount;

    final useFirstItems = dashboardData.useFirstItems;
    final expiringSoonItems = dashboardData.expiringSoonItems;
    final recentItems = dashboardData.recentItems;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Inventory Summary (Greeting + Stats)
              HomeGreetingHeader(
                firstName: firstName,
                householdName: ref
                    .watch(currentHouseholdStreamProvider)
                    .valueOrNull
                    ?.name,
              ),
              HomeStatsBoard(
                totalCount: totalCount,
                expiringSoonCount: expiringSoonCount,
                expiredCount: expiredCount,
                onExpiredTap: () => context.push(AppRouteNames.wasteStatistics),
              ),
              SizedBox(height: 18.h),
              Material(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => context.push(AppRouteNames.aiAssistant),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 15.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          size: 21.r,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hỏi trợ lý FOORA',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate800,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                'Gõ hoặc nói để hỏi về thực phẩm trong tủ',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 18.r,
                          color: AppColors.slate500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Material(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => context.push(AppRouteNames.nearbyStores),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 15.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.mapPinned,
                          size: 21.r,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tìm nơi đi chợ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate800,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                'Xem siêu thị và chợ ở gần vị trí của bạn',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 18.r,
                          color: AppColors.slate500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (totalCount == 0)
                Padding(
                  padding: EdgeInsets.only(top: 32.h),
                  child: const EmptyStateWidget(
                    title: 'Tủ lạnh đang trống',
                    subtitle:
                        'Thêm thực phẩm thủ công hoặc quét hóa đơn để bắt đầu theo dõi hạn dùng.',
                  ),
                ),

              // 2. Use First (Horizontal Scroll)
              if (useFirstItems.isNotEmpty) ...[
                HomeSectionHeader(
                  title: 'Ưu tiên sử dụng',
                  barColor: AppColors.red500,
                ),
                SizedBox(
                  height: 160.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: useFirstItems.length,
                    itemBuilder: (context, index) {
                      return HomeHorizontalItemCard(
                        item: useFirstItems[index],
                        onTap: () {
                          context.push(
                            AppRouteNames.itemForm,
                            extra: useFirstItems[index],
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 24.h),
              ],

              // 3. Expiring Soon (Vertical List)
              if (expiringSoonItems.isNotEmpty) ...[
                HomeSectionHeader(
                  title: 'Sắp hết hạn',
                  barColor: AppColors.amber500,
                ),
                ...expiringSoonItems.map(
                  (item) => HomeVerticalItemCard(
                    item: item,
                    onTap: () {
                      context.push(AppRouteNames.itemForm, extra: item);
                    },
                  ),
                ),
                SizedBox(height: 14.h),
              ],

              // 4. Recent / Quick Inventory (2-column grid)
              if (recentItems.isNotEmpty) ...[
                HomeSectionHeader(
                  title: 'Vừa thêm gần đây',
                  barColor: AppColors.blue500,
                  showSeeAll: false,
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10.w,
                    mainAxisSpacing: 10.h,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: recentItems.length,
                  itemBuilder: (context, index) {
                    return HomeRecentItemCard(
                      item: recentItems[index],
                      onTap: () {
                        context.push(
                          AppRouteNames.itemForm,
                          extra: recentItems[index],
                        );
                      },
                    );
                  },
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
