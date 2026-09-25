import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_menu.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: LoadingWidget(message: 'Đang tải hồ sơ cá nhân...'),
        ),
        error: (error, _) => Center(
          child: Text(
            'Không thể tải hồ sơ: $error',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.red600),
            textAlign: TextAlign.center,
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Chưa có thông tin người dùng.'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12.w, 24.h, 12.w, 40.h),
            child: Column(
              children: [
                _ProfileHeaderCard(
                  fullName: profile.fullName,
                  email: profile.email,
                  avatarUrl: profile.avatarUrl,
                  initials: profile.initials,
                  onEdit: () => context.push(AppRouteNames.profileDetail),
                ),
                SizedBox(height: 36.h),
                ProfileMenuSection(
                  title: 'TÀI KHOẢN',
                  children: [
                    ProfileMenuTile(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: AppColors.amber600,
                      iconBgColor: AppColors.amber50,
                      title: 'Gói thành viên',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MembershipBadge(isPremium: profile.isPremium),
                          SizedBox(width: 8.w),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18.r,
                            color: AppColors.slate300,
                          ),
                        ],
                      ),
                      showDivider: false,
                      onTap: () => context.push(AppRouteNames.myMembership),
                    ),
                  ],
                ),
                ProfileMenuSection(
                  title: 'CÀI ĐẶT & BẢO MẬT',
                  children: [
                    ProfileMenuTile(
                      icon: LucideIcons.lock,
                      title: 'Đổi mật khẩu',
                      onTap: () => ChangePasswordDialog.show(context),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.bell,
                      title: 'Thông báo',
                      showDivider: false,
                      onTap: () =>
                          context.push(AppRouteNames.notificationSettings),
                    ),
                  ],
                ),
                ProfileMenuSection(
                  title: 'HỖ TRỢ',
                  children: [
                    ProfileMenuTile(
                      icon: LucideIcons.circleHelp,
                      title: 'Trung tâm trợ giúp',
                      onTap: () => context.push(AppRouteNames.helpCenter),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.messageCircle,
                      title: 'Liên hệ',
                      onTap: () => context.push(AppRouteNames.contactUs),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.bug,
                      title: 'Báo lỗi',
                      onTap: () => context.push(AppRouteNames.reportBug),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.star,
                      title: 'Đánh giá',
                      showDivider: false,
                      onTap: () => _showComingSoon(context, 'Đánh giá'),
                    ),
                  ],
                ),
                ProfileMenuSection(
                  title: 'THÔNG TIN ỨNG DỤNG',
                  children: [
                    ProfileMenuTile(
                      icon: LucideIcons.info,
                      title: 'Về FOORA',
                      onTap: () => context.push(AppRouteNames.helpCenter),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.bookOpen,
                      title: 'Hướng dẫn sử dụng',
                      onTap: () => context.push(AppRouteNames.helpCenter),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.share2,
                      title: 'Chia sẻ FOORA',
                      onTap: () => _showComingSoon(context, 'Chia sẻ'),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.shield,
                      title: 'Chính sách bảo mật',
                      onTap: () => context.push(AppRouteNames.privacySettings),
                    ),
                    ProfileMenuTile(
                      icon: LucideIcons.fileText,
                      title: 'Điều khoản sử dụng',
                      showDivider: false,
                      onTap: () => context.push(AppRouteNames.privacySettings),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleLogout(context, ref),
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red600,
                      backgroundColor: AppColors.red50,
                      side: const BorderSide(color: AppColors.red100),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      textStyle: AppTextStyles.bodyMedium.copyWith(
                        fontFamily: AppTextStyles.fontFamilyHeadline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28.h),
                Text(
                  'FOORA v1.0.0',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate400,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ToastHelper.show(context, '$feature sẽ sớm được cập nhật.');
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: 'Đăng xuất tài khoản',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi FOORA trên thiết bị này?',
      confirmText: 'Đăng xuất',
      cancelText: 'Ở lại',
      icon: LucideIcons.logOut,
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) {
      ToastHelper.show(context, 'Đã đăng xuất tài khoản.');
      context.go(AppRouteNames.auth);
    }
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.initials,
    required this.onEdit,
  });

  final String fullName;
  final String email;
  final String? avatarUrl;
  final String initials;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.slate200.withValues(alpha: 0.9),
          width: 1.2.r,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.10),
            blurRadius: 18.r,
            spreadRadius: -3.r,
            offset: Offset(0, 10.h),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 28.r,
            spreadRadius: -8.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Row(
        children: [
          ProfileAvatar(size: 96, imageUrl: avatarUrl, initials: initials),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Người dùng FOORA' : fullName,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  email,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),
                OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 7.h,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Chỉnh sửa hồ sơ',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.amber50 : AppColors.slate50,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        isPremium ? 'PREMIUM' : 'FREE',
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: isPremium ? AppColors.amber600 : AppColors.slate500,
        ),
      ),
    );
  }
}
