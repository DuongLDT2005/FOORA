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
    String typeLabel;

    switch (notification.type) {
      case NotificationType.expirationAlert:
        iconColor = AppColors.red600;
        iconBgColor = AppColors.red50;
        iconData = LucideIcons.triangleAlert;
        typeLabel = 'Đã quá hạn';
        break;
      case NotificationType.upcomingExpiration:
        iconColor = AppColors.amber600;
        iconBgColor = AppColors.amber50;
        iconData = LucideIcons.clock;
        typeLabel = 'Sắp hết hạn';
        break;
      case NotificationType.priorityFood:
        iconColor = AppColors.emerald800;
        iconBgColor = AppColors.emerald50;
        iconData = LucideIcons.sparkles;
        typeLabel = 'Gợi ý thông minh';
        break;
      case NotificationType.system:
        iconColor = AppColors.primary;
        iconBgColor = AppColors.emerald50;
        iconData = LucideIcons.bell;
        typeLabel = 'Thông tin';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.emerald50 : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isUnread ? AppColors.emerald100 : AppColors.slate100,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A08121B),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(width: 8.w),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16.r,
                        color: AppColors.slate300,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          typeLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: iconColor,
                            fontSize: 10.sp,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        SizedBox(width: 7.w),
                        Container(
                          key: const Key('notification-unread-dot'),
                          width: 7.r,
                          height: 7.r,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 7.h),
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
