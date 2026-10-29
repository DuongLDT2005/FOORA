import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/shopping_item.dart';

/// "2" for whole numbers, "1.5" otherwise.
String formatShoppingQuantity(double quantity) =>
    quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

/// Rounded checkbox used by shopping rows.
class ShoppingCheckbox extends StatelessWidget {
  final bool checked;

  const ShoppingCheckbox({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22.r,
      height: 22.r,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: checked ? AppColors.primary : AppColors.slate300,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(
              LucideIcons.check,
              size: 15.r,
              color: AppColors.surfaceContainerLowest,
            )
          : null,
    );
  }
}

/// One shopping item: tap to tick it as bought, edit or delete it. Items
/// already moved into the fridge are read-only.
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
    final isLocked = item.isLocked;
    final isPurchased = item.isPurchased;
    final radius = BorderRadius.circular(14.r);
    final note = item.note;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.slate100),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: isLocked ? null : () => onTogglePurchased(!isPurchased),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 12.h),
            child: Row(
              children: [
                ShoppingCheckbox(checked: isPurchased),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isPurchased
                              ? AppColors.slate400
                              : AppColors.slate800,
                          decoration: isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        [
                          '${formatShoppingQuantity(item.quantity)} ${item.unit}',
                          if (note != null && note.isNotEmpty) note,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 12.sp,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w, right: 8.w),
                    child: const _InFridgeBadge(),
                  )
                else ...[
                  _TileIconButton(
                    icon: LucideIcons.pencil,
                    color: AppColors.slate400,
                    onPressed: onEdit,
                  ),
                  _TileIconButton(
                    icon: LucideIcons.trash2,
                    color: AppColors.red500,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TileIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18.r, color: color),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InFridgeBadge extends StatelessWidget {
  const _InFridgeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.emerald50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.emerald200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.packageCheck,
            size: 12.r,
            color: AppColors.emerald700,
          ),
          SizedBox(width: 4.w),
          Text(
            'Đã nhập kho',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamilySans,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.emerald700,
            ),
          ),
        ],
      ),
    );
  }
}
