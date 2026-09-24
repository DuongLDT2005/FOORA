import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/routes/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../widgets/app_button.dart';

/// Shell Scaffold for Mobile Tabs (Home, Inventory, Scan, Profile)
/// Provides sticky header and custom bottom bar while hiding both for Scan tab.
class MobileShellScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final currentIndex = navigationShell.currentIndex;
    final isScanTab = currentIndex == 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isScanTab
          ? null
          : _MobileShellHeader(
              userInitial: _getUserInitial(user?.displayName, user?.email),
              onNotificationTap: () {
                context.push(AppRouteNames.notifications);
              },
            ),
      body: navigationShell,
      floatingActionButton: isScanTab
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: AppFloatingActionButton(
                onPressed: () {
                  context.push(AppRouteNames.itemForm);
                },
              ),
            ),
      bottomNavigationBar: isScanTab
          ? null
          : _MobileBottomNavBar(
              currentIndex: currentIndex,
              onTabSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
    );
  }

  String _getUserInitial(String? displayName, String? email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final names = displayName.trim().split(' ');
      if (names.length >= 2) {
        return '${names.first[0]}${names.last[0]}'.toUpperCase();
      }
      return names.first
          .substring(0, names.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'UR';
  }
}

/// Sticky Header Widget for Mobile Shell
class _MobileShellHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final String userInitial;
  final VoidCallback onNotificationTap;

  const _MobileShellHeader({
    required this.userInitial,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: AppColors.slate100.withAlpha(128),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: User Initial Avatar + Brand Name
              Row(
                children: [
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      color: AppColors.emerald100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryFixed,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      userInitial,
                      style: GoogleFonts.lexend(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'FOORA',
                    style: GoogleFonts.lexend(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Right: Notification Bell Button with Unread Badge
              IconButton(
                onPressed: onNotificationTap,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      LucideIcons.bell,
                      size: 22.r,
                      color: AppColors.slate500,
                    ),
                    Positioned(
                      top: -2.h,
                      right: -2.w,
                      child: Container(
                        padding: EdgeInsets.all(3.r),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 8.r,
                          minHeight: 8.r,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Thông báo',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(64.h);
}

/// Rounded Bottom Navigation Bar for Mobile Shell
class _MobileBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _MobileBottomNavBar({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(245),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        border: const Border(
          top: BorderSide(color: AppColors.slate100, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20.r,
            offset: Offset(0, -6.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: LucideIcons.house,
                activeIcon: LucideIcons.house,
                label: 'Trang chủ',
              ),
              _buildNavItem(
                index: 1,
                icon: LucideIcons.refrigerator,
                activeIcon: LucideIcons.refrigerator,
                label: 'Tủ lạnh',
              ),
              _buildNavItem(
                index: 2,
                icon: LucideIcons.scanLine,
                activeIcon: LucideIcons.scanLine,
                label: 'Quét mã',
              ),
              _buildNavItem(
                index: 3,
                icon: LucideIcons.user,
                activeIcon: LucideIcons.user,
                label: 'Cá nhân',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = index == currentIndex;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        transform: isSelected
            ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
            : Matrix4.identity(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22.r,
              color: isSelected ? AppColors.primary : AppColors.slate400,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
