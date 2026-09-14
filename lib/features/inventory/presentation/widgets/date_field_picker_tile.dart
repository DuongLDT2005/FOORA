import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';

/// Date Picker Tile matching AppTextField aesthetics
class DateFieldPickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const DateFieldPickerTile({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label.toUpperCase(),
            style: AppTextStyles.inputLabel.copyWith(
              color: AppColors.slate600,
              fontSize: 12.sp,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.red500),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.formatDate(date),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: AppColors.slate800,
                  ),
                ),
                Icon(
                  LucideIcons.calendar,
                  size: 20.r,
                  color: AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
