import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_button.dart';

// --- AppErrorBanner ---
class AppErrorBanner extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AppErrorBanner({
    super.key,
    required this.message,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: margin ?? EdgeInsets.only(bottom: 16.h),
      child: Container(
        padding: padding ?? EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.red50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.red100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.shieldAlert,
              color: AppColors.red600,
              size: 16.r,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.red600,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.sp,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ErrorStateWidget ---
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    this.title = 'Đã xảy ra lỗi',
    this.message = 'Không thể tải dữ liệu vào lúc này. Vui lòng kiểm tra lại kết nối và thử lại.',
    this.onRetry,
    this.retryText = 'Thử lại',
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.slate100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48.r, color: AppColors.red500),
              SizedBox(height: 16.h),
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.slate800,
                  fontSize: 18.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.slate500,
                  fontSize: 14.sp,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: 20.h),
                SizedBox(
                  width: 160.w,
                  child: SecondaryButton(text: retryText, onPressed: onRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
