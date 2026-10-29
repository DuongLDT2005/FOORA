import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../providers/notification_settings_provider.dart';

/// Vietnamese weekday labels indexed by ISO weekday (1 = Monday).
const Map<int, String> _weekdayLabels = {
  1: 'Thứ Hai',
  2: 'Thứ Ba',
  3: 'Thứ Tư',
  4: 'Thứ Năm',
  5: 'Thứ Sáu',
  6: 'Thứ Bảy',
  7: 'Chủ nhật',
};

/// Notification settings: push toggle, expiry-alert days, reminder hour and
/// the weekly shopping reminder. Synced to Firestore so the backend reminder
/// job honors them (PLAN_02).
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationSettingsProvider);
    final settings = state.settings;
    final notifier = ref.read(notificationSettingsProvider.notifier);

    ref.listen(notificationSettingsProvider.select((s) => s.errorMessage), (
      _,
      message,
    ) {
      if (message != null) {
        ToastHelper.show(context, message, isError: true);
        notifier.clearError();
      }
    });

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
                value: settings.pushEnabled,
                onChanged: notifier.togglePush,
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.volume2,
                title: 'Âm thanh thông báo',
                subtitle: 'Phát âm thanh khi có cảnh báo mới',
                value: state.soundEnabled,
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
                value: settings.hasExpiryAlert(1),
                onChanged: (v) => notifier.toggleExpiryAlert(1, v),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.clock,
                iconColor: AppColors.amber600,
                iconBgColor: AppColors.amber50,
                title: 'Trước 3 ngày (Sớm)',
                subtitle: 'Ưu tiên tiêu thụ trước khi bị hỏng',
                value: settings.hasExpiryAlert(3),
                onChanged: (v) => notifier.toggleExpiryAlert(3, v),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.calendarCheck,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.emerald50,
                title: 'Trước 7 ngày (Kế hoạch)',
                subtitle: 'Lên thực đơn tuần cho thực phẩm sắp tới hạn',
                value: settings.hasExpiryAlert(7),
                onChanged: (v) => notifier.toggleExpiryAlert(7, v),
              ),
            ]),
            SizedBox(height: 20.h),

            // Section 3: Reminder hour (the backend job runs hourly)
            _buildSectionHeader('Giờ nhắc nhở'),
            _buildCard([
              _buildValueTile(
                icon: LucideIcons.alarmClock,
                title: 'Giờ nhắc nhở mỗi ngày',
                subtitle:
                    'Thông báo được gửi khoảng ${state.formattedReminderHour} '
                    '(giờ Việt Nam)',
                value: state.formattedReminderHour,
                onTap: () => BottomSheetHelper.showSelect<int>(
                  context,
                  title: 'Chọn giờ nhắc',
                  selectedValue: settings.reminderHour,
                  isGrid: true,
                  options: [
                    for (var h = 0; h < 24; h++)
                      SelectOption(
                        value: h,
                        label: '${h.toString().padLeft(2, '0')}:00',
                      ),
                  ],
                  onSelected: notifier.setReminderHour,
                ),
              ),
            ]),
            SizedBox(height: 20.h),

            // Section 4: Weekly shopping reminder
            _buildSectionHeader('Nhắc đi chợ hằng tuần'),
            _buildCard([
              _buildSwitchTile(
                icon: LucideIcons.shoppingCart,
                title: 'Nhắc đi chợ',
                subtitle: 'Nhắc danh sách cần mua và gợi ý hay mua',
                value: settings.shoppingReminderEnabled,
                onChanged: notifier.toggleShoppingReminder,
              ),
              if (settings.shoppingReminderEnabled) ...[
                _buildDivider(),
                _buildValueTile(
                  icon: LucideIcons.calendarDays,
                  title: 'Ngày nhắc',
                  subtitle: 'Gửi vào giờ nhắc nhở đã chọn ở trên',
                  value: _weekdayLabels[settings.shoppingReminderWeekday]!,
                  onTap: () => BottomSheetHelper.showSelect<int>(
                    context,
                    title: 'Chọn ngày nhắc đi chợ',
                    selectedValue: settings.shoppingReminderWeekday,
                    options: [
                      for (final entry in _weekdayLabels.entries)
                        SelectOption(value: entry.key, label: entry.value),
                    ],
                    onSelected: notifier.setShoppingWeekday,
                  ),
                ),
              ],
            ]),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  /// Row with a value chip on the right that opens a picker.
  Widget _buildValueTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.r, color: AppColors.primary),
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
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.emerald100,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                value,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small layout helpers shared by the sections.
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
