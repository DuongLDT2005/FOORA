import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../domain/entities/inventory_item.dart';
import '../food_image_avatar.dart'; // Maybe we need to use CachedNetworkImage or similar. But since we don't have the original FoodImageAvatar that fits rectangle, I'll use a placeholder or image widget.

class HomeHorizontalItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;

  const HomeHorizontalItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntilExpiry = DateFormatter.getDaysUntilExpiry(item.expirationDate);
    final isUrgent = daysUntilExpiry <= 1;
    
    final badgeBgColor = isUrgent ? AppColors.red50 : AppColors.amber50;
    final badgeTextColor = isUrgent ? AppColors.red700 : AppColors.amber700;
    final badgeBorderColor = isUrgent ? AppColors.red100 : AppColors.amber100;
    final badgeText = daysUntilExpiry == 0 
        ? 'Hôm nay' 
        : (daysUntilExpiry == 1 ? 'Ngày mai' : 'Còn $daysUntilExpiry ngày');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120.w, // min-w-[130px]
        margin: EdgeInsets.only(right: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image part
            SizedBox(
              height: 72.h, // h-20
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.slate50,
                    child: Icon(Icons.fastfood, color: AppColors.slate200, size: 24.sp),
                  ),
                  if (item.photoUrl != null)
                    Image.network(item.photoUrl!, fit: BoxFit.cover),
                  
                  // Badge
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: badgeBorderColor),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w900,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Info part
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  // Progress Bar
                  Container(
                    height: 4.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (item.remainingPercentage / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.red500,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // Meta text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lượng: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate400,
                        ),
                      ),
                      Text(
                        '${item.remainingPercentage}%',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
