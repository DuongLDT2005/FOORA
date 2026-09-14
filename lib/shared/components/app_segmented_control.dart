import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SegmentedItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? badgeCount;

  const SegmentedItem({
    required this.value,
    required this.label,
    this.icon,
    this.badgeCount,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final T selectedValue;
  final List<SegmentedItem<T>> items;
  final ValueChanged<T> onValueChanged;
  final Color selectedColor;
  final Color unselectedTextColor;
  final Color backgroundColor;
  final TextStyle? textStyle;

  const AppSegmentedControl({
    super.key,
    required this.selectedValue,
    required this.items,
    required this.onValueChanged,
    this.selectedColor = AppColors.primary,
    this.unselectedTextColor = AppColors.slate400,
    this.backgroundColor = AppColors.slate100,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item.value == selectedValue;

          return Expanded(
            child: GestureDetector(
              onTap: () => onValueChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4.r,
                            offset: Offset(0, 2.h),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16.r,
                        color: isSelected ? selectedColor : unselectedTextColor,
                      ),
                      SizedBox(width: 6.w),
                    ],
                    Text(
                      item.label,
                      style:
                          (textStyle ??
                                  AppTextStyles.headlineSmall.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ))
                              .copyWith(
                                color: isSelected
                                    ? selectedColor
                                    : unselectedTextColor,
                              ),
                    ),
                    if (item.badgeCount != null && item.badgeCount! > 0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColor.withValues(alpha: 0.1)
                              : AppColors.slate200,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? selectedColor
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
