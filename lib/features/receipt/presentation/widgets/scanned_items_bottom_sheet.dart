import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../inventory/presentation/widgets/food_image_avatar.dart';
import '../../domain/entities/receipt_item.dart';

/// Scanned Items Preview Bottom Sheet matching Stitch design `Quét hóa đơn (Đã cập nhật List)`
class ScannedItemsBottomSheet extends StatelessWidget {
  final List<ReceiptItem> items;
  final bool isSubmitting;
  final ValueChanged<int> onItemTap;
  final ValueChanged<int> onItemDelete;
  final VoidCallback onAddAll;

  const ScannedItemsBottomSheet({
    super.key,
    required this.items,
    required this.isSubmitting,
    required this.onItemTap,
    required this.onItemDelete,
    required this.onAddAll,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520.w, // Ergonomic width on tablets & desktop browsers
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                    width: 44.w,
                    height: 4.5.h,
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ),

                // Header summary bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32.r,
                        height: 32.r,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.sparkles,
                            color: AppColors.primary,
                            size: 16.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hóa đơn vừa quét',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate800,
                              ),
                            ),
                            Text(
                              'Tìm thấy ${items.length} món',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11.sp,
                                color: AppColors.slate500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // "Thêm tất cả" button
                      ElevatedButton.icon(
                        onPressed: isSubmitting ? null : onAddAll,
                        icon: isSubmitting
                            ? SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(LucideIcons.plus, size: 14.r),
                        label: Text(
                          'Thêm tất cả (${items.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 8.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.slate100),

                // Scrollable list of items
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.44,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ScannedItemCard(
                        item: item,
                        onTap: () => onItemTap(index),
                        onDelete: () => onItemDelete(index),
                      );
                    },
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

class _ScannedItemCard extends StatelessWidget {
  final ReceiptItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScannedItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasStockAlert = item.matchedExistingItem != null;
    final qtyString = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category icon / food avatar
                FoodImageAvatar(
                  photoUrl: item.photoUrl,
                  categoryId: item.categoryId,
                  size: 38,
                  borderRadius: 12,
                ),
                SizedBox(width: 10.w),

                // Name with arrow
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.chevron_right,
                        size: 18.r,
                        color: AppColors.slate400,
                      ),
                    ],
                  ),
                ),

                // Quantity badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '$qtyString ${item.unit}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),

                // Quick delete button
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    width: 28.r,
                    height: 28.r,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close,
                        size: 14.r,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Smart Inventory FEFO Alert Banner if item already exists in fridge
            if (hasStockAlert) ...[
              SizedBox(height: 8.h),
              _buildStockAlertBanner(item.matchedExistingItem!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlertBanner(dynamic alert) {
    final existingQty = alert.quantity % 1 == 0
        ? alert.quantity.toInt().toString()
        : alert.quantity.toString();

    final days = alert.daysRemaining as int;
    final timeBadgeText = days <= 0
        ? 'Hết hôm nay'
        : (days == 1 ? 'Hết ngày mai' : 'Còn $days ngày');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.amber200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14.r,
                color: AppColors.amber600,
              ),
              SizedBox(width: 4.w),
              Text(
                'ĐÃ CÓ SẴN TRONG TỦ',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.amber700,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '$existingQty ${alert.unit}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    const Text(
                      '•',
                      style: TextStyle(color: AppColors.slate300),
                    ),
                    SizedBox(width: 6.w),
                    Icon(Icons.ac_unit, size: 12.r, color: AppColors.primary),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        alert.storageLocationName.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.sp,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  timeBadgeText,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
