import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../components/app_bottom_bar.dart';
import '../components/app_header.dart';

/// Common Page Scaffold Layout for subpages (ItemForm, Notifications, ProfileDetail, Membership, PaymentHistory)
class SubpageLayout extends StatelessWidget {
  final AppHeader header;
  final Widget body;
  final Widget? bottomNavigationBar;
  final AppBottomBar? bottomBar;
  final Color backgroundColor;

  const SubpageLayout({
    super.key,
    required this.header,
    required this.body,
    this.bottomNavigationBar,
    this.bottomBar,
    this.backgroundColor = AppColors.background,
  });

  /// Layout for Item Form (`/inventory/item-form`)
  factory SubpageLayout.itemForm({
    Key? key,
    required bool isEditing,
    required Widget body,
    VoidCallback? onBack,
    VoidCallback? onCancel,
    VoidCallback? onSubmit,
    bool isSubmitting = false,
  }) {
    return SubpageLayout(
      key: key,
      header: AppHeader.itemForm(
        isEditing: isEditing,
        onBack: onBack ?? onCancel,
      ),
      bottomBar: AppBottomBar.form(
        onCancel: onCancel ?? onBack,
        onSubmit: onSubmit,
        submitLabel: isEditing ? 'Cập nhật thực phẩm' : 'Lưu thông tin',
        isSubmitting: isSubmitting,
      ),
      body: body,
    );
  }

  /// Layout for Profile Detail (`/profile/detail`)
  factory SubpageLayout.profileDetail({
    Key? key,
    required Widget body,
    VoidCallback? onBack,
    VoidCallback? onCancel,
    VoidCallback? onSubmit,
    bool isSubmitting = false,
  }) {
    return SubpageLayout(
      key: key,
      header: AppHeader.profileDetail(
        onBack: onBack ?? onCancel,
      ),
      bottomBar: AppBottomBar.form(
        onCancel: onCancel ?? onBack,
        onSubmit: onSubmit,
        submitLabel: 'Lưu thay đổi',
        isSubmitting: isSubmitting,
      ),
      body: body,
    );
  }

  /// Layout for Membership (`/membership`)
  factory SubpageLayout.membership({
    Key? key,
    required bool isPremium,
    required Widget body,
    VoidCallback? onBack,
    VoidCallback? onUpgrade,
    VoidCallback? onManage,
    bool isLoading = false,
  }) {
    return SubpageLayout(
      key: key,
      header: AppHeader.membership(
        isPremium: isPremium,
        onBack: onBack,
      ),
      bottomBar: AppBottomBar.membership(
        isPremium: isPremium,
        onUpgrade: onUpgrade,
        onManage: onManage,
        isLoading: isLoading,
      ),
      body: body,
    );
  }

  /// Layout for Notifications (`/notifications`)
  factory SubpageLayout.notifications({
    Key? key,
    required Widget body,
    VoidCallback? onBack,
    int unreadCount = 0,
    VoidCallback? onMarkAllAsRead,
  }) {
    return SubpageLayout(
      key: key,
      header: AppHeader.notifications(
        unreadCount: unreadCount,
        onMarkAllAsRead: onMarkAllAsRead,
        onBack: onBack,
      ),
      body: body,
    );
  }

  /// Layout for Payment History (`/payment-history`)
  factory SubpageLayout.paymentHistory({
    Key? key,
    required Widget body,
    VoidCallback? onBack,
  }) {
    return SubpageLayout(
      key: key,
      header: AppHeader.paymentHistory(
        onBack: onBack,
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600.w),
          child: Column(
            children: [
              header,
              Expanded(child: body),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (bottomBar != null || bottomNavigationBar != null)
          ? Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600.w),
                child: bottomBar ?? bottomNavigationBar,
              ),
            )
          : null,
    );
  }
}
