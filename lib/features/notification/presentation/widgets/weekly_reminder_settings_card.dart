import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/weekly_reminder_provider.dart';

/// Card widget presenting the Weekly Shopping Reminder settings:
/// - Enable/Disable toggle (FR-01, Section 5)
/// - Day of week selector (FR-02, Section 5)
/// - Time picker (FR-03, Section 5)
/// - Sample preview & schedule summary (FR-04, FR-05, Section 5)
/// - Permission prompt banner (BR-05, AT-07)
class WeeklyReminderSettingsCard extends ConsumerWidget {
  const WeeklyReminderSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weeklyReminderProvider);
    final notifier = ref.read(weeklyReminderProvider.notifier);
    final config = state.config;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Toggle switch
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    LucideIcons.shoppingBag,
                    size: 18.r,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Shopping Reminder',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.slate800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Nhận thông báo định kỳ mỗi tuần để chuẩn bị mua sắm',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slate500,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('weekly_reminder_switch'),
                  value: config.isEnabled,
                  onChanged: (val) async {
                    await notifier.toggleReminder(val);
                  },
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.emerald100,
                ),
              ],
            ),
          ),

          // 2. Expanded settings when reminder is enabled
          if (config.isEnabled) ...[
            // Permission warning alert if notifications are disabled on the device
            if (!state.hasNotificationPermission) ...[
              _buildDivider(),
              Container(
                margin: EdgeInsets.all(12.r),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.amber200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      color: AppColors.amber600,
                      size: 20.r,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quyền thông báo chưa được cấp',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.amber700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Ứng dụng đã lưu lịch nhưng thông báo sẽ không thể hiển thị nếu chưa có quyền.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate700,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          ElevatedButton.icon(
                            key: const Key('grant_permission_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 8.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(LucideIcons.bellRing, size: 14),
                            label: const Text(
                              'Cấp quyền thông báo ngay',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () async {
                              await notifier.requestPermission();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            _buildDivider(),

            // 3. Day of week selector
            InkWell(
              key: const Key('weekly_reminder_day_selector'),
              onTap: () => _showDayPickerSheet(context, config.dayOfWeek, notifier),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        LucideIcons.calendar,
                        size: 18.r,
                        color: AppColors.slate700,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày nhắc trong tuần',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.slate800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Chọn ngày cố định từ Thứ Hai đến Chủ Nhật',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate500,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald100,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        config.dayNameVi,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildDivider(),

            // 4. Time selector
            InkWell(
              key: const Key('weekly_reminder_time_selector'),
              onTap: () async {
                final initialTime = TimeOfDay(
                  hour: config.hour,
                  minute: config.minute,
                );
                final picked = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          onSurface: AppColors.slate900,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  await notifier.setReminderTime(picked.hour, picked.minute);
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        LucideIcons.alarmClock,
                        size: 18.r,
                        color: AppColors.slate700,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giờ nhắc mua sắm',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.slate800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Thời điểm hệ thống nhắc bạn vào ngày đã chọn',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate500,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald100,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        config.formattedTime,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildDivider(),

            // 5. Sample Preview & Summary (Section 5)
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.emerald50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.emerald100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.bellRing,
                          size: 14.r,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Mẫu thông báo khi đến lịch:',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOORA — Nhắc nhở mua sắm',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.slate800,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Đến lúc kiểm tra danh sách mua sắm tuần này!',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 12.r,
                          color: AppColors.slate400,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            'Chạm vào thông báo để mở nhanh Danh sách mua sắm.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate500,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      config.summaryText,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDayPickerSheet(
    BuildContext context,
    int currentDay,
    WeeklyReminderNotifier notifier,
  ) {
    final days = [
      (DateTime.monday, 'Thứ Hai'),
      (DateTime.tuesday, 'Thứ Ba'),
      (DateTime.wednesday, 'Thứ Tư'),
      (DateTime.thursday, 'Thứ Năm'),
      (DateTime.friday, 'Thứ Sáu'),
      (DateTime.saturday, 'Thứ Bảy'),
      (DateTime.sunday, 'Chủ Nhật'),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar
                SizedBox(height: 12.h),
                Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),

                // Sheet Header with Primary Emerald Accent
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          LucideIcons.calendar,
                          color: AppColors.primary,
                          size: 20.r,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chọn ngày nhắc trong tuần',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate900,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Hệ thống sẽ gửi thông báo kiểm tra mua sắm vào ngày này',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12.sp,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                SizedBox(height: 8.h),

                // Scrollable Day Options (Handles overbottom overflow cleanly)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                    child: Column(
                      children: days.map((d) {
                        final (dayNumber, dayName) = d;
                        final isSelected = dayNumber == currentDay;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.emerald50 : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.slate200,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.r),
                              onTap: () {
                                Navigator.pop(ctx);
                                notifier.setDayOfWeek(dayNumber);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 14.h,
                                ),
                                child: Row(
                                  children: [
                                    // Day Badge Icon (Primary Color)
                                    Container(
                                      width: 32.r,
                                      height: 32.r,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.slate100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          dayNumber == DateTime.sunday
                                              ? 'CN'
                                              : 'T$dayNumber',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.slate700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Text(
                                        dayName,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.slate800,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: EdgeInsets.all(4.r),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          LucideIcons.check,
                                          color: Colors.white,
                                          size: 14.r,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 18.r,
                                        height: 18.r,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.slate300,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 68.w),
      child: const Divider(height: 1, thickness: 1, color: AppColors.slate100),
    );
  }
}
