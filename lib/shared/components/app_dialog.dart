import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../widgets/app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isDestructive;

  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Xác nhận',
    this.cancelText = 'Hủy',
    this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor = AppColors.primary,
    this.iconBgColor = const Color(0xFFF0FDF4),
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420.w),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? AppColors.red500.withValues(alpha: 0.1)
                        : iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28.r,
                    color: isDestructive ? AppColors.red500 : iconColor,
                  ),
                ),
                SizedBox(height: 16.h),
              ],
              Text(
                title,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.slate600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  if (cancelText != null) ...[
                    Expanded(
                      child: SecondaryButton(
                        text: cancelText!,
                        onPressed:
                            onCancel ?? () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                  ],
                  Expanded(
                    child: isDestructive
                        ? DangerButton(
                            text: confirmText,
                            onPressed:
                                onConfirm ?? () => Navigator.of(context).pop(),
                          )
                        : PrimaryButton(
                            text: confirmText,
                            onPressed:
                                onConfirm ?? () => Navigator.of(context).pop(),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
