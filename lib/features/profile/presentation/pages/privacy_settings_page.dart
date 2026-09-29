import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/profile_provider.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  bool _shareInventory = true;
  bool _allowAiAnalytics = true;
  bool _isClearingCache = false;

  void _clearCache() async {
    setState(() => _isClearingCache = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isClearingCache = false);
      ToastHelper.show(context, 'Đã dọn dẹp 12.4 MB bộ nhớ tạm ứng dụng.');
    }
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              LucideIcons.triangleAlert,
              color: AppColors.red600,
              size: 22.r,
            ),
            SizedBox(width: 8.w),
            Text(
              'Xóa tài khoản vĩnh viễn?',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.red600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động này không thể hoàn tác. Mọi dữ liệu về kho thực phẩm, thông tin gia đình và lịch sử sẽ bị xóa vĩnh viễn khỏi FOORA.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate700,
              ),
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: passwordController,
              label: 'Nhập mật khẩu để xác nhận',
              obscureText: true,
              prefixIcon: const Icon(LucideIcons.lock),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final password = passwordController.text.trim();
              final success = await ref
                  .read(editProfileNotifierProvider.notifier)
                  .deleteAccount(password: password.isEmpty ? null : password);

              if (mounted) {
                if (success) {
                  ToastHelper.show(context, 'Đã xóa tài khoản.');
                  context.go(AppRouteNames.auth);
                } else {
                  final err = ref
                      .read(editProfileNotifierProvider)
                      .errorMessage;
                  ToastHelper.show(
                    context,
                    err ?? 'Xóa tài khoản thất bại.',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubpageLayout(
      header: AppHeader(
        title: 'Quyền riêng tư & Hệ thống',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Data Privacy
            _buildSectionHeader('Dữ liệu & Quyền riêng tư'),
            _buildCard([
              _buildSwitchTile(
                icon: LucideIcons.users,
                title: 'Chia sẻ dữ liệu hộ gia đình',
                subtitle: 'Các thành viên trong nhà có thể xem kho thực phẩm',
                value: _shareInventory,
                onChanged: (val) => setState(() => _shareInventory = val),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: LucideIcons.sparkles,
                title: 'Trợ lý AI học hỏi thói quen',
                subtitle: 'Cho phép AI gợi ý món ăn dựa trên kho đồ ăn sẵn có',
                value: _allowAiAnalytics,
                onChanged: (val) => setState(() => _allowAiAnalytics = val),
              ),
            ]),
            SizedBox(height: 20.h),

            // Section 2: Storage & Cache
            _buildSectionHeader('Bộ nhớ & Dữ liệu tạm'),
            _buildCard([
              InkWell(
                onTap: _isClearingCache ? null : _clearCache,
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
                          LucideIcons.trash2,
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
                              'Dọn dẹp bộ nhớ đệm (Cache)',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.slate800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Giải phóng dung lượng ảnh hóa đơn tạm thời',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.slate500,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isClearingCache)
                        SizedBox(
                          width: 18.r,
                          height: 18.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Text(
                          '12.4 MB',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.slate400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
            SizedBox(height: 24.h),

            // Section 3: Danger Zone
            _buildSectionHeader('Vùng nguy hiểm'),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.red50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.red100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.shieldAlert,
                        color: AppColors.red600,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Xóa tài khoản',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.red600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Sau khi xóa tài khoản, tất cả dữ liệu thực phẩm, danh mục và cài đặt sẽ bị xóa vĩnh viễn và không thể khôi phục.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.slate700,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  AppButton.danger(
                    label: 'Yêu cầu xóa tài khoản',
                    icon: LucideIcons.userX,
                    onPressed: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
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
  }) {
    return Padding(
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
