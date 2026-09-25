import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/inventory_item.dart';
import 'food_image_avatar.dart';

enum ExpirationGroupType { expired, today, tomorrow, upcoming, safe }

class ExpirationItemCard extends StatelessWidget {
  final InventoryItem item;
  final String categoryName;
  final String storageLocationName;
  final ExpirationGroupType groupType;
  final VoidCallback onSwipeDelete;

  const ExpirationItemCard({
    super.key,
    required this.item,
    required this.categoryName,
    required this.storageLocationName,
    required this.groupType,
    required this.onSwipeDelete,
  });

  Color _getBadgeBackgroundColor() {
    switch (groupType) {
      case ExpirationGroupType.expired:
        return AppColors.red50;
      case ExpirationGroupType.today:
        return AppColors.amber50;
      case ExpirationGroupType.tomorrow:
        return AppColors.amber50;
      case ExpirationGroupType.upcoming:
        return AppColors.amber50;
      case ExpirationGroupType.safe:
        return AppColors.emerald50;
    }
  }

  Color _getBadgeTextColor() {
    switch (groupType) {
      case ExpirationGroupType.expired:
        return AppColors.red700;
      case ExpirationGroupType.today:
      case ExpirationGroupType.tomorrow:
      case ExpirationGroupType.upcoming:
        return AppColors.amber700;
      case ExpirationGroupType.safe:
        return AppColors.emerald700;
    }
  }

  Color _getBadgeBorderColor() {
    switch (groupType) {
      case ExpirationGroupType.expired:
        return AppColors.red100;
      case ExpirationGroupType.today:
      case ExpirationGroupType.tomorrow:
      case ExpirationGroupType.upcoming:
        return AppColors.amber100;
      case ExpirationGroupType.safe:
        return AppColors.emerald100;
    }
  }

  String _getBadgeText() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfExpiry = DateTime(
      item.expirationDate.year,
      item.expirationDate.month,
      item.expirationDate.day,
    );

    switch (groupType) {
      case ExpirationGroupType.expired:
        final days = startOfToday.difference(startOfExpiry).inDays;
        return 'QUÁ HẠN $days NGÀY';
      case ExpirationGroupType.today:
        return 'HÔM NAY';
      case ExpirationGroupType.tomorrow:
        return 'NGÀY MAI';
      case ExpirationGroupType.upcoming:
      case ExpirationGroupType.safe:
        final days = startOfExpiry.difference(startOfToday).inDays;
        return 'CÒN $days NGÀY';
    }
  }

  Color _getProgressBarColor() {
    switch (groupType) {
      case ExpirationGroupType.expired:
        return AppColors.red500;
      case ExpirationGroupType.today:
      case ExpirationGroupType.tomorrow:
      case ExpirationGroupType.upcoming:
        return AppColors.amber500;
      case ExpirationGroupType.safe:
        return AppColors.emerald500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.red100,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Dismissible(
        key: Key('expiration_card_${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) => onSwipeDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(LucideIcons.trash2, color: AppColors.red600, size: 24.r),
        ),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: groupType == ExpirationGroupType.expired
                  ? AppColors.slate100.withValues(alpha: 0.7)
                  : AppColors.slate200.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ColorFiltered(
                colorFilter: groupType == ExpirationGroupType.expired
                    ? const ColorFilter.matrix([
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: groupType == ExpirationGroupType.expired
                          ? AppColors.red100
                          : AppColors.slate100,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: FoodImageAvatar(
                      photoUrl: item.photoUrl,
                      categoryId: item.categoryId,
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Title and Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.sp,
                              color: groupType == ExpirationGroupType.expired
                                  ? AppColors.slate500
                                  : AppColors.slate800,
                              decoration:
                                  groupType == ExpirationGroupType.expired
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getBadgeBackgroundColor(),
                            border: Border.all(color: _getBadgeBorderColor()),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            _getBadgeText(),
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w900,
                              color: _getBadgeTextColor(),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50.withValues(alpha: 0.8),
                        border: Border.all(
                          color: AppColors.emerald100.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.thermometer,
                            size: 9.sp,
                            color: AppColors.emerald500,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            storageLocationName,
                            style: TextStyle(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // Middle row: Quantity and Percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lượng còn: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                        Text(
                          '${item.remainingPercentage}%',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    // Progress bar
                    Container(
                      height: 4.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (item.remainingPercentage / 100).clamp(
                          0.0,
                          1.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getProgressBarColor(),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // Bottom row: Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'HSD: ${DateFormatter.formatDate(item.expirationDate)}',
                          style: TextStyle(
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 8.sp,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
