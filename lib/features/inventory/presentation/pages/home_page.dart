import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../providers/expiration_list_provider.dart';
import '../providers/inventory_provider.dart';

import '../widgets/home/home_greeting_header.dart';
import '../widgets/home/home_stats_board.dart';
import '../widgets/home/home_section_header.dart';
import '../widgets/home/home_horizontal_item_card.dart';
import '../widgets/home/home_vertical_item_card.dart';
import '../widgets/home/home_recent_item_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final displayName = user?.displayName ?? 'Khách';
    final firstName = displayName.split(' ').last;

    // Fetch states
    final expirationState = ref.watch(expirationListNotifierProvider);
    final activeItemsAsync = ref.watch(activeHouseholdInventoryStreamProvider);

    final totalCount = activeItemsAsync.valueOrNull?.length ?? 0;
    
    // 2. Use First (Horizontal Scroll) -> today + tomorrow + upcoming
    final useFirstItems = [
      ...expirationState.todayItems,
      ...expirationState.tomorrowItems,
      ...expirationState.upcomingItems,
    ].take(10).toList(); // Max 10 items

    // 3. Expiring Soon (Vertical List) -> urgent items
    final expiringSoonItems = [
      ...expirationState.todayItems,
      ...expirationState.tomorrowItems,
    ].take(5).toList();

    // 4. Recent Items
    final allItems = activeItemsAsync.valueOrNull?.toList() ?? [];
    allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentItems = allItems.take(4).toList();

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
                expiringSoonCount: expirationState.urgentCount,
                expiredCount: expirationState.spoiledCount,
              ),
              
              // 2. Use First (Horizontal Scroll)
              if (useFirstItems.isNotEmpty) ...[
                HomeSectionHeader(title: 'Ưu tiên sử dụng', barColor: AppColors.red500),
                SizedBox(
                  height: 160.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: useFirstItems.length,
                    itemBuilder: (context, index) {
                      return HomeHorizontalItemCard(
                        item: useFirstItems[index],
                        onTap: () {
                          context.pushNamed(AppRouteNames.itemForm, extra: useFirstItems[index]);
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 24.h),
              ],
              
              // 3. Expiring Soon (Vertical List)
              if (expiringSoonItems.isNotEmpty) ...[
                HomeSectionHeader(title: 'Sắp hết hạn', barColor: AppColors.amber500),
                ...expiringSoonItems.map((item) => HomeVerticalItemCard(
                  item: item,
                  onTap: () {
                    context.pushNamed(AppRouteNames.itemForm, extra: item);
                  },
                )),
                SizedBox(height: 14.h),
              ],
              
              // 4. Recent / Quick Inventory (2-column grid)
              if (recentItems.isNotEmpty) ...[
                HomeSectionHeader(
                  title: 'Vừa thêm gần đây', 
                  barColor: AppColors.blue500,
                  showSeeAll: false, // In design, this doesn't have "Tất cả"
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
                        context.pushNamed(AppRouteNames.itemForm, extra: recentItems[index]);
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
