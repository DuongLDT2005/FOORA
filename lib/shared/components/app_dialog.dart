import 'package:flutter/material.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.red500.withValues(alpha: 0.1)
                      : iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDestructive ? AppColors.red500 : iconColor,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.slate600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: SecondaryButton(
                      text: cancelText!,
                      onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: isDestructive
                      ? DangerButton(
                          text: confirmText,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onConfirm?.call();
                          },
                        )
                      : PrimaryButton(
                          text: confirmText,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onConfirm?.call();
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
