import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final ValueChanged<bool> onTogglePurchased;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onTogglePurchased,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = item.isAddedToInventory;
    final isPurchased = item.isPurchased;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isPurchased ? AppColors.slate200 : AppColors.slate100,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: isLocked ? null : () => onTogglePurchased(!isPurchased),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                // Custom Checkbox
                GestureDetector(
                  onTap: isLocked ? null : () => onTogglePurchased(!isPurchased),
                  child: Container(
                    width: 22.r,
                    height: 22.r,
                    decoration: BoxDecoration(
                      color: isPurchased ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isPurchased ? AppColors.primary : AppColors.slate300,
                        width: 1.5,
                      ),
                    ),
                    child: isPurchased
                        ? Icon(
                            LucideIcons.check,
                            size: 15.r,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: isPurchased ? AppColors.slate400 : AppColors.slate800,
                                decoration: isPurchased ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLocked) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: AppColors.emerald200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.packageCheck,
                                    size: 12.r,
                                    color: AppColors.emerald600,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Đã nhập kho',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(
                            '${_formatQuantity(item.quantity)} ${item.unit}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isPurchased ? AppColors.slate400 : AppColors.slate600,
                            ),
                          ),
                          if (item.note != null && item.note!.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Text(
                              '•',
                              style: TextStyle(fontSize: 12.sp, color: AppColors.slate300),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                item.note!,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit & Delete actions (only if not yet locked / added to inventory)
                if (!isLocked) ...[
                  IconButton(
                    icon: Icon(
                      LucideIcons.pencil,
                      size: 16.r,
                      color: AppColors.slate400,
                    ),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18.r,
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 16.r,
                      color: AppColors.red500,
                    ),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18.r,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double q) {
    if (q == q.roundToDouble()) {
      return q.toInt().toString();
    }
    return q.toString();
  }
}
