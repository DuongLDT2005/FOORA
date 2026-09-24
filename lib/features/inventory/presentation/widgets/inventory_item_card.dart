import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/food_category.dart';
import 'food_image_avatar.dart';

/// Food item card with progress bar, expiration state styling, and swipe-to-delete
/// Built exactly to FOORA AI HTML Design spec
class InventoryItemCard extends StatelessWidget {
  final String id;
  final String name;
  final String quantity;
  final String unit;
  final int percentageRemaining;
  final String? imageUrl;
  final FoodCategory? category;
  final String storageLocationId; // 'fridge' or 'freezer'
  final DateTime expirationDate;
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
    this.category,
    required this.storageLocationId,
    required this.expirationDate,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final expiryStatus = DateFormatter.getExpiryStatus(expirationDate);
    final daysUntilExpiry = DateFormatter.getDaysUntilExpiry(expirationDate);
    final isExpired = expiryStatus == ExpiryStatus.expired;
    final isWarning = expiryStatus == ExpiryStatus.expiringSoon;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.red100,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Dismissible(
        key: Key(id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(LucideIcons.trash2, color: AppColors.red600, size: 24.r),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.slate100.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image with expired filter
                _buildImage(isExpired),
                SizedBox(width: 12.w),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Title and Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14.sp, // ~11px in web
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
                          SizedBox(width: 8.w),
                          _buildStatusBadge(
                            isExpired,
                            isWarning,
                            daysUntilExpiry,
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      _buildStorageBadge(),
                      SizedBox(height: 6.h),
                      // Middle row: Quantity and percentage
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lượng còn: $quantity $unit',
                              style: TextStyle(
                                fontSize: 12.sp, // ~9px in web
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate400,
                              ),
                            ),
                          ),
                          Text(
                            '$percentageRemaining%',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      // Progress Bar
                      Container(
                        height: 4.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (percentageRemaining / 100).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? AppColors.red500
                                  : (isWarning
                                        ? AppColors.amber500
                                        : AppColors.emerald500),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // Bottom row: Expiry Date, Category
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'HSD: ${DateFormatter.formatDate(expirationDate)}',
                            style: TextStyle(
                              fontSize: 11.sp, // ~8px in web
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate400,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.slate400,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              category?.name ?? 'Chưa phân loại',
                              style: TextStyle(
                                fontSize: 11.sp,
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
      ),
    );
  }

  Widget _buildImage(bool isExpired) {
    Widget imageWidget = FoodImageAvatar(
      photoUrl: imageUrl,
      categoryId: category?.id ?? 'vegetables',
      size: 56, // 14 * 4
      borderRadius: 12,
      backgroundColor: AppColors.slate50,
    );

    if (isExpired) {
      return Container(
        width: 56.r,
        height: 56.r,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.red100),
        ),
        child: Stack(
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
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
              ]),
              child: imageWidget,
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.red900.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.shieldAlert,
                color: AppColors.red600,
                size: 20.r,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: imageWidget,
    );
  }

  Widget _buildStatusBadge(
    bool isExpired,
    bool isWarning,
    int daysUntilExpiry,
  ) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    String text;

    if (isExpired) {
      bgColor = AppColors.red50;
      textColor = AppColors.red700;
      borderColor = AppColors.red100;
      final daysText = daysUntilExpiry.abs() > 0
          ? ' ${daysUntilExpiry.abs()} NGÀY'
          : '';
      text = 'QUÁ HẠN$daysText';
    } else if (isWarning) {
      bgColor = AppColors.amber50;
      textColor = AppColors.amber700;
      borderColor = AppColors.amber100;
      text = daysUntilExpiry == 0
          ? 'HẾT HẠN HÔM NAY'
          : 'CÒN $daysUntilExpiry NGÀY';
    } else {
      bgColor = AppColors.emerald50;
      textColor = AppColors.emerald700;
      borderColor = AppColors.emerald100;
      text = 'TƯƠI NGON';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp, // ~8px in web
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStorageBadge() {
    final isFridge = storageLocationId == 'fridge';
    final bgColor = isFridge
        ? AppColors.emerald50.withValues(alpha: 0.8)
        : const Color(0xFFECFEFF); // Cyan-50
    final textColor = isFridge
        ? AppColors.emerald700
        : const Color(0xFF0E7490); // Cyan-700
    final borderColor = isFridge
        ? AppColors.emerald100.withValues(alpha: 0.5)
        : const Color(0xFFCFFAFE); // Cyan-100
    final iconData = isFridge ? LucideIcons.thermometer : LucideIcons.snowflake;
    final label = isFridge ? 'Ngăn mát' : 'Ngăn đông';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 10.r,
            color: isFridge ? AppColors.emerald500 : const Color(0xFF06B6D4),
          ),
          SizedBox(width: 2.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
