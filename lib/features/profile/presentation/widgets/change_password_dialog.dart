import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/profile_provider.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;

    final success = await ref
        .read(editProfileNotifierProvider.notifier)
        .changePassword(currentPassword: currentPass, newPassword: newPass);

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(editProfileNotifierProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      LucideIcons.shieldAlert,
                      color: AppColors.primary,
                      size: 18.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Đổi mật khẩu tài khoản',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Mật khẩu mới phải có ít nhất 6 ký tự để bảo vệ tài khoản của bạn.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.slate500,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Current password
              AppTextField(
                controller: _currentPasswordController,
                label: 'Mật khẩu hiện tại',
                placeholder: 'Nhập mật khẩu đang sử dụng',
                obscureText: _obscureCurrent,
                prefixIcon: const Icon(LucideIcons.keyRound),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18.r,
                    color: AppColors.slate400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                validator: (val) =>
                    InputValidators.validateRequired(val, 'Mật khẩu hiện tại'),
              ),
              SizedBox(height: 14.h),

              // New password
              AppTextField(
                controller: _newPasswordController,
                label: 'Mật khẩu mới',
                placeholder: 'Tối thiểu 6 ký tự',
                obscureText: _obscureNew,
                prefixIcon: const Icon(LucideIcons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18.r,
                    color: AppColors.slate400,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: InputValidators.validatePassword,
              ),
              SizedBox(height: 14.h),

              // Confirm password
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Xác nhận mật khẩu mới',
                placeholder: 'Nhập lại mật khẩu mới',
                obscureText: _obscureConfirm,
                prefixIcon: const Icon(LucideIcons.checkCheck),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18.r,
                    color: AppColors.slate400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu mới';
                  }
                  if (val != _newPasswordController.text) {
                    return 'Mật khẩu xác nhận không trùng khớp';
                  }
                  return null;
                },
              ),

              if (editState.errorMessage != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.red50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 16.r,
                        color: AppColors.red600,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          editState.errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.red600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 20.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Hủy bỏ',
                      onPressed: editState.isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Xác nhận',
                      isLoading: editState.isLoading,
                      onPressed: editState.isLoading ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
