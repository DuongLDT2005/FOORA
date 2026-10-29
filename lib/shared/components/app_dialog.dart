import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../widgets/app_button.dart';

/// Reusable styled dialog with icon, title, message and confirm/cancel actions.
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// Optional destructive action shown between cancel and confirm.
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final IconData? icon;
  final IconData? confirmIcon;
  final IconData? secondaryIcon;
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
    this.secondaryText,
    this.onSecondary,
    this.icon,
    this.confirmIcon,
    this.secondaryIcon,
    this.iconColor = AppColors.primary,
    this.iconBgColor = AppColors.green50,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420.w),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 58.r,
                  height: 58.r,
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
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
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
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              if (secondaryText != null) ...[
                // Choice layout: Two balanced primary actions (Vứt bỏ & Đã dùng);
                // labels shrink to fit instead of wrapping, as in AppButton.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSecondary,
                        icon: Icon(
                          secondaryIcon ?? LucideIcons.trash2,
                          size: 17.r,
                          color: AppColors.red600,
                        ),
                        label: AppButtonLabel(
                          secondaryText!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.red50,
                          side: const BorderSide(color: AppColors.red100),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            onConfirm ?? () => Navigator.of(context).pop(),
                        icon: Icon(
                          confirmIcon ?? LucideIcons.check,
                          size: 18.r,
                          color: Colors.white,
                        ),
                        label: AppButtonLabel(
                          confirmText,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.primary.withValues(
                            alpha: 0.35,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (cancelText != null) ...[
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onCancel ?? () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slate500,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: AppButtonLabel(
                        cancelText!,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Standard 2-button layout (Cancel / Confirm)
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
                                  onConfirm ??
                                  () => Navigator.of(context).pop(),
                            )
                          : PrimaryButton(
                              text: confirmText,
                              onPressed:
                                  onConfirm ??
                                  () => Navigator.of(context).pop(),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
