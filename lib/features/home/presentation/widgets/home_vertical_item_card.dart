import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../inventory/domain/entities/inventory_item.dart';

class HomeVerticalItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;

  const HomeVerticalItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntilExpiry = DateFormatter.getDaysUntilExpiry(
      item.expirationDate,
    );
    final isUrgent = daysUntilExpiry <= 1;

    final badgeBgColor = isUrgent ? AppColors.red50 : AppColors.amber50;
    final badgeTextColor = isUrgent ? AppColors.red700 : AppColors.amber700;
    final badgeBorderColor = isUrgent ? AppColors.red100 : AppColors.amber100;
    final badgeText = daysUntilExpiry == 0
        ? 'Hôm nay'
        : (daysUntilExpiry == 1 ? 'Còn 1 ngày' : 'Còn $daysUntilExpiry ngày');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 56.w, // w-14
                    height: 56.w, // h-14
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.photoUrl != null
                        ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.fastfood,
                            color: AppColors.slate200,
                            size: 24.sp,
                          ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: badgeBgColor,
                border: Border.all(color: badgeBorderColor),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
