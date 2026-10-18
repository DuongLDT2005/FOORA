import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';

/// Required "ĐƠN VỊ" field that opens a grid bottom sheet of [units].
class UnitPickerField extends StatelessWidget {
  const UnitPickerField({
    super.key,
    required this.unit,
    required this.units,
    required this.onChanged,
  });

  final String unit;
  final List<String> units;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'ĐƠN VỊ',
            style: AppTextStyles.inputLabel.copyWith(color: AppColors.slate600),
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
          onTap: () {
            BottomSheetHelper.showSelect<String>(
              context,
              title: 'Đơn vị tính',
              isGrid: true,
              selectedValue: unit,
              options: units
                  .map((u) => SelectOption(value: u, label: u))
                  .toList(),
              onSelected: onChanged,
            );
          },
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
                  unit,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 24.r,
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
