import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../providers/notification_settings_provider.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return SubpageLayout(
      header: AppHeader(
        title: 'Cài đặt thông báo',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Push Notifications
            _buildSectionHeader('Thông báo thiết bị'),
            _buildCard([
              _buildSwitchTile(
                icon: LucideIcons.bellRing,
                title: 'Thông báo đẩy (Push)',
                subtitle: 'Nhận cảnh báo ngay cả khi không mở ứng dụng',
                value: settings.isPushEnabled,
                onChanged: notifier.togglePush,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.volume2,
                title: 'Âm thanh thông báo',
                subtitle: 'Phát âm thanh khi có cảnh báo mới',
                value: settings.soundEnabled,
                onChanged: notifier.toggleSound,
              ),
            ]),
            SizedBox(height: 20.h),

            // Section 2: FEFO Expiry Rules
            _buildSectionHeader('Chu kỳ cảnh báo hết hạn (FEFO)'),
            _buildCard([
              _buildSwitchTile(
                icon: LucideIcons.triangleAlert,
                iconColor: AppColors.red600,
                iconBgColor: AppColors.red50,
                title: 'Trước 1 ngày (Khẩn cấp)',
                subtitle: 'Thực phẩm sẽ hết hạn vào ngày mai',
                value: settings.expiryAlert1Day,
                onChanged: notifier.toggleExpiry1Day,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.clock,
                iconColor: AppColors.amber600,
                iconBgColor: AppColors.amber50,
                title: 'Trước 3 ngày (Sớm)',
                subtitle: 'Ưu tiên tiêu thụ trước khi bị hỏng',
                value: settings.expiryAlert3Days,
                onChanged: notifier.toggleExpiry3Days,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.calendarCheck,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.emerald50,
                title: 'Trước 7 ngày (Kế hoạch)',
                subtitle: 'Lên thực đơn tuần cho thực phẩm sắp tới hạn',
                value: settings.expiryAlert7Days,
                onChanged: notifier.toggleExpiry7Days,
              ),
            ]),
            SizedBox(height: 20.h),

            // Section 3: Daily Reminder Time
            _buildSectionHeader('Thời gian nhắc nhở hàng ngày'),
            _buildCard([
              InkWell(
                onTap: () async {
                  final initialTime = TimeOfDay(
                    hour: settings.reminderHour,
                    minute: settings.reminderMinute,
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
                borderRadius: BorderRadius.circular(16.r),
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
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          LucideIcons.alarmClock,
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
                              'Giờ nhắc nhở mỗi ngày',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.slate800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Thời điểm hệ thống gửi thông báo tổng hợp',
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
                          settings.formattedReminderTime,
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
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
      child: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.slate500,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
    Color? iconBgColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 38.r,
            height: 38.r,
            decoration: BoxDecoration(
              color: iconBgColor ?? AppColors.emerald50,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              size: 18.r,
              color: iconColor ?? AppColors.primary,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate500,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.emerald100,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 68.w),
      child: const Divider(height: 1, thickness: 1, color: AppColors.slate100),
    );
  }
}
