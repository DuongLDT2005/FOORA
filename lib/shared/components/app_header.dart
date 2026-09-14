import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// --- AppHeader ---
/// Unified top bar header matching the design system:
/// - Background: [AppColors.primary]
/// - Text: White, Lexend bold
/// - Back chevron button with rounded hover/tap highlight
/// - Flexible trailing action / badge slots for specific screen variants
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? action;

  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.action,
  });

  /// Variant for Item Form (`/inventory/item-form`)
  factory AppHeader.itemForm({
    Key? key,
    required bool isEditing,
    VoidCallback? onBack,
  }) {
    return AppHeader(
      key: key,
      title: isEditing ? 'Chỉnh sửa thực phẩm' : 'Thêm thực phẩm',
      onBack: onBack,
    );
  }

  /// Variant for Notifications (`/notifications`)
  factory AppHeader.notifications({
    Key? key,
    VoidCallback? onBack,
    int unreadCount = 0,
    VoidCallback? onMarkAllAsRead,
  }) {
    return AppHeader(
      key: key,
      title: 'Thông báo',
      onBack: onBack,
      trailing: unreadCount > 0 && onMarkAllAsRead != null
          ? _HeaderMarkAllReadButton(onPressed: onMarkAllAsRead)
          : null,
    );
  }

  /// Variant for Profile Detail (`/profile/detail`)
  factory AppHeader.profileDetail({
    Key? key,
    VoidCallback? onBack,
    Widget? action,
  }) {
    return AppHeader(
      key: key,
      title: 'Hồ sơ cá nhân',
      onBack: onBack,
      trailing: action,
    );
  }

  /// Variant for Membership (`/membership`)
  factory AppHeader.membership({
    Key? key,
    VoidCallback? onBack,
    bool isPremium = false,
  }) {
    return AppHeader(
      key: key,
      title: 'Gói thành viên',
      onBack: onBack,
      trailing: isPremium ? const _HeaderPremiumBadge() : null,
    );
  }

  /// Variant for Payment History (`/payment-history`)
  factory AppHeader.paymentHistory({Key? key, VoidCallback? onBack}) {
    return AppHeader(key: key, title: 'Lịch sử thanh toán', onBack: onBack);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing = trailing ?? action;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: const Color(0x26000000), // shadow-md
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: topPadding > 0 ? topPadding + 6.h : 14.h,
        bottom: 14.h,
        left: 8.w,
        right: 20.w,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Back button + Title
          Expanded(
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBack ?? () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(999),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.15),
                    child: Padding(
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 32.r,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontSize: 22.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Action / Badge (if any)
          if (effectiveTrailing != null) ...[
            SizedBox(width: 12.w),
            effectiveTrailing,
          ],
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(62.h);
}

/// Action button: "Mark all as read"
class _HeaderMarkAllReadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeaderMarkAllReadButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        splashColor: Colors.white.withValues(alpha: 0.25),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 16.r, color: Colors.white),
              SizedBox(width: 4.w),
              Text(
                'Đã đọc hết',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge: "PREMIUM" with Crown icon
class _HeaderPremiumBadge extends StatelessWidget {
  const _HeaderPremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.amber.shade300.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 15.r,
            color: Colors.amber.shade300,
          ),
          SizedBox(width: 4.w),
          Text(
            'PREMIUM',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: Colors.amber.shade300,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
