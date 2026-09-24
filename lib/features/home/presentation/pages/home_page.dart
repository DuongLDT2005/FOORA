import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
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
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final displayName = user?.displayName ?? 'Khách';
    final firstName = displayName.split(' ').last;

    // Watch home domain dashboard state directly from home module provider
    final dashboardAsync = ref.watch(homeDashboardStreamProvider);
    final dashboardData = dashboardAsync.valueOrNull;

    final totalCount = dashboardData?.totalCount ?? 0;
    final expiringSoonCount = dashboardData?.expiringSoonCount ?? 0;
    final expiredCount = dashboardData?.expiredCount ?? 0;

    final useFirstItems = dashboardData?.useFirstItems ?? [];
    final expiringSoonItems = dashboardData?.expiringSoonItems ?? [];
    final recentItems = dashboardData?.recentItems ?? [];

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
              HomeGreetingHeader(firstName: firstName),
              HomeStatsBoard(
                totalCount: totalCount,
                expiringSoonCount: expiringSoonCount,
                expiredCount: expiredCount,
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
                          context.pushNamed(
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
                      context.pushNamed(AppRouteNames.itemForm, extra: item);
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
                        context.pushNamed(
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
