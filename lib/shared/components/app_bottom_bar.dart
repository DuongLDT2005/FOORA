import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// --- AppBottomBar (Common Bottom Bar for Mobile Pages) ---
/// Unified bottom bar matching the design system:
/// - Container: White with top border [AppColors.slate100], safe-area bottom padding, shadow
/// - Provides named factory constructors for:
///   - [AppBottomBar.form]: For item-form & profile-detail (Cancel + Save info with Save icon & loading state)
///   - [AppBottomBar.membership]: For membership page (!isPremium: price + Upgrade Premium / isPremium: Manage plan)
///   - [AppBottomBar.custom]: Allows fully custom child content
class AppBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppBottomBar({
    super.key,
    required this.child,
    this.padding,
  });

  /// Variant 1: Form Action Bar (Used for `item-form`, `profile-detail`)
  /// Consists of 2 buttons:
  /// - Cancel: flex 1, slate-100 color, slate-600 text
  /// - Save: flex 2, primary color (FOORA green), Save icon, white text, supports isLoading & disabled
  factory AppBottomBar.form({
    Key? key,
    required VoidCallback? onCancel,
    required VoidCallback? onSubmit,
    String cancelLabel = 'Hủy',
    String submitLabel = 'Lưu thông tin',
    IconData submitIcon = Icons.save_outlined,
    bool isSubmitting = false,
  }) {
    return AppBottomBar(
      key: key,
      child: Row(
        children: [
          // Cancel button (Flex 1)
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 50.h,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate100,
                  foregroundColor: AppColors.slate600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  cancelLabel,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Save info button (Flex 2)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50.h,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 22.r,
                        height: 22.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(submitIcon, size: 20.r, color: Colors.white),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              submitLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Variant 2: Membership Action Bar (Used for `membership` page)
  factory AppBottomBar.membership({
    Key? key,
    required bool isPremium,
    required VoidCallback? onUpgrade,
    required VoidCallback? onManage,
    bool isLoading = false,
  }) {
    return AppBottomBar(
      key: key,
      child: isPremium
          ? SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: isLoading ? null : onManage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate100,
                  foregroundColor: AppColors.slate700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: const BorderSide(color: AppColors.slate200),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 22.r,
                        height: 22.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.slate600),
                        ),
                      )
                    : Text(
                        'Quản lý gói đăng ký',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate700,
                        ),
                      ),
              ),
            )
          : Row(
              children: [
                // Price information
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG THANH TOÁN',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.slate400,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.sp,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '29.000đ',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '/tháng',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(width: 16.w),
                // Upgrade button
                Expanded(
                  child: SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 22.r,
                              height: 22.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Nâng cấp Premium',
                              style: AppTextStyles.tabLabel.copyWith(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Center(
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600.w),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.slate100, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x08000000), // shadow 2-3%
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 14.h,
            bottom: bottomInset > 0 ? bottomInset + 4.h : 16.h,
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: child,
          ),
        ),
      ),
    );
  }
}

// Alias for backward compatibility
typedef StickyBottomActions = AppBottomBar;
