import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Data model representing a selectable option in AppSelectBottomSheet
class SelectOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;

  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });
}

/// Generic Reusable Bottom Sheet for Single-Selection (List or Wrap/Grid format)
class AppSelectBottomSheet<T> extends StatelessWidget {
  final List<SelectOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final bool isGrid;
  final String? description;

  const AppSelectBottomSheet({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.isGrid = false,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Text(
              description!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate500,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
        if (isGrid) _buildGrid(context) else _buildList(context),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: options.map((opt) {
        final isSelected = opt.value == selectedValue;
        return InkWell(
          onTap: () {
            onSelected(opt.value);
            Navigator.pop(context, opt.value);
          },
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.slate200,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (opt.leading != null) ...[
                  opt.leading!,
                  const SizedBox(width: 8),
                ],
                Text(
                  opt.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.slate700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final opt = options[index];
        final isSelected = opt.value == selectedValue;

        return InkWell(
          onTap: () {
            onSelected(opt.value);
            Navigator.pop(context, opt.value);
          },
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.slate100,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (opt.leading != null) ...[
                  opt.leading!,
                  SizedBox(width: 12.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.slate800,
                          fontSize: 14.sp,
                        ),
                      ),
                      if (opt.subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          opt.subtitle!,
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.8)
                                : AppColors.slate400,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 20.r,
                  height: 20.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.slate300,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 14.r,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
