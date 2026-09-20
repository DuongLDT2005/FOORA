import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import 'food_image_avatar.dart';

/// Food item card with progress bar, expiration state styling, and swipe-to-delete
class InventoryItemCard extends StatelessWidget {
  final String id;
  final String name;
  final String quantity;
  final String unit;
  final int percentageRemaining;
  final String? imageUrl;
  final String categoryId;
  final int daysUntilExpiry; // < 0: Expired, 0-3: Expiring soon
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const InventoryItemCard({
    super.key,
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.percentageRemaining,
    this.imageUrl,
    this.categoryId = 'vegetables',
    required this.daysUntilExpiry,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = daysUntilExpiry < 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.red500.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Dismissible(
        key: Key(id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(Icons.delete, color: AppColors.red500, size: 24.r),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              children: [
                // Image with expired grayscale filter
                ColorFiltered(
                  colorFilter: isExpired
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
                  child: FoodImageAvatar(
                    photoUrl: imageUrl,
                    categoryId: categoryId,
                    size: 56,
                    borderRadius: 12,
                    backgroundColor: AppColors.slate50,
                  ),
                ),
                SizedBox(width: 12.w),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isExpired
                                    ? AppColors.slate400
                                    : AppColors.slate800,
                                decoration: isExpired
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isExpired)
                                StatusBadge.expired()
                              else if (daysUntilExpiry <= 3)
                                StatusBadge.warning(),
                              if (isExpired || daysUntilExpiry <= 3)
                                SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.slate50,
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(color: AppColors.slate100),
                                ),
                                child: Text(
                                  '$quantity $unit',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      // Progress Bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: percentageRemaining / 100,
                                backgroundColor: AppColors.slate100,
                                color: isExpired
                                    ? AppColors.slate300
                                    : AppColors.primary,
                                minHeight: 6.h,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '$percentageRemaining%',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate400,
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
      ),
    );
  }
}
