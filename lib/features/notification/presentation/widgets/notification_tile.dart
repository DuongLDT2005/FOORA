import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/app_notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const NotificationTile({super.key, required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    Color iconColor;
    Color iconBgColor;
    IconData iconData;

    switch (notification.type) {
      case NotificationType.expirationAlert:
        iconColor = AppColors.red600;
        iconBgColor = AppColors.red50;
        iconData = LucideIcons.triangleAlert;
        break;
      case NotificationType.upcomingExpiration:
        iconColor = AppColors.amber600;
        iconBgColor = AppColors.amber50;
        iconData = LucideIcons.clock;
        break;
      case NotificationType.priorityFood:
        iconColor = AppColors.emerald800;
        iconBgColor = AppColors.emerald50;
        iconData = LucideIcons.sparkles;
        break;
      case NotificationType.system:
        iconColor = AppColors.primary;
        iconBgColor = AppColors.emerald50;
        iconData = LucideIcons.bell;
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.emerald50.withValues(alpha: 0.35)
              : Colors.white,
          border: const Border(
            bottom: BorderSide(color: AppColors.slate100, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Icon(iconData, size: 20.r, color: iconColor),
              ),
            ),
            SizedBox(width: 14.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.slate900,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        SizedBox(width: 6.w),
                        Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.slate600,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    DateFormatter.formatDate(notification.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.slate400,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
