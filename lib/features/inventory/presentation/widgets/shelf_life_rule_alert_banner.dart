import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Alert banner displaying shelf life recommendation below expiration date field
class ShelfLifeRuleAlertBanner extends StatelessWidget {
  final num? maxValue;
  final String? unit;
  final String storageLocationName;
  final bool hasRule;

  const ShelfLifeRuleAlertBanner({
    super.key,
    this.maxValue,
    this.unit,
    required this.storageLocationName,
    required this.hasRule,
  });

  String _formatUnit(String? unit) {
    switch (unit) {
      case 'days':
        return 'ngày';
      case 'weeks':
        return 'tuần';
      case 'months':
        return 'tháng';
      case 'years':
        return 'năm';
      default:
        return unit ?? 'ngày';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hasRule && maxValue != null) {
      final unitStr = _formatUnit(unit);
      final valueStr = maxValue! % 1 == 0 ? maxValue!.toInt().toString() : maxValue.toString();

      return Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.amber50,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.amber200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Icon(
                LucideIcons.clock,
                size: 16.r,
                color: AppColors.amber600,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.amber800,
                    height: 1.4,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'Khuyên dùng bảo quản tối đa '),
                    TextSpan(
                      text: '$valueStr $unitStr ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: 'trong $storageLocationName.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Case when no rule exists or storage location is not recommended
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(
              LucideIcons.info,
              size: 16.r,
              color: AppColors.slate400,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Chưa có thông tin bảo quản cho vị trí này',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.slate500,
                fontSize: 11.sp,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
