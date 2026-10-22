import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_segmented_control.dart';

/// Period selector widget for the Waste Statistics page.
/// Allows the user to pick between 3, 6, or 12 months.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.selectedMonths,
    required this.onChanged,
  });

  final int selectedMonths;
  final ValueChanged<int> onChanged;

  static const _periods = [
    SegmentedItem(value: 3, label: '3 tháng'),
    SegmentedItem(value: 6, label: '6 tháng'),
    SegmentedItem(value: 12, label: '12 tháng'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kỳ thống kê',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 12.sp,
              color: AppColors.slate400,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          AppSegmentedControl<int>(
            selectedValue: selectedMonths,
            items: _periods,
            onValueChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
