import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';

/// Interactive date range picker selector for the Waste Statistics page.
/// Allows the user to select custom start and end dates via a calendar dialog
/// and provides convenient quick preset chips (7 days, 30 days, this month, 3 months).
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

  final DateTime startDate;
  final DateTime endDate;
  final void Function(DateTime start, DateTime end) onDateRangeChanged;

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: startDate.isAfter(now) ? now : startDate,
        end: endDate.isAfter(DateTime(now.year + 1)) ? now : endDate,
      ),
      locale: const Locale('vi', 'VN'),
      saveText: 'Áp dụng',
      helpText: 'Chọn khoảng thời gian thống kê',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.slate800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateRangeChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormatter.formatDate(startDate);
    final endStr = DateFormatter.formatDate(endDate);

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khoảng thời gian',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.slate400,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            child: InkWell(
              onTap: () => _pickDateRange(context),
              borderRadius: BorderRadius.circular(16.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        LucideIcons.calendarDays,
                        color: AppColors.primary,
                        size: 18.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thời gian áp dụng',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate400,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '$startStr - $endStr',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chọn lịch',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate600,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            LucideIcons.calendar,
                            size: 13.r,
                            color: AppColors.slate600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                  label: '7 ngày qua',
                  onTap: () {
                    final now = DateTime.now();
                    onDateRangeChanged(
                      now.subtract(const Duration(days: 6)),
                      now,
                    );
                  },
                ),
                SizedBox(width: 6.w),
                _QuickChip(
                  label: '30 ngày qua',
                  onTap: () {
                    final now = DateTime.now();
                    onDateRangeChanged(
                      now.subtract(const Duration(days: 29)),
                      now,
                    );
                  },
                ),
                SizedBox(width: 6.w),
                _QuickChip(
                  label: 'Tháng này',
                  onTap: () {
                    final now = DateTime.now();
                    onDateRangeChanged(DateTime(now.year, now.month, 1), now);
                  },
                ),
                SizedBox(width: 6.w),
                _QuickChip(
                  label: '3 tháng qua',
                  onTap: () {
                    final now = DateTime.now();
                    onDateRangeChanged(
                      DateTime(now.year, now.month - 2, 1),
                      now,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
