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

class ChangeEmailDialog extends ConsumerStatefulWidget {
  final String currentEmail;

  const ChangeEmailDialog({super.key, required this.currentEmail});

  static Future<bool?> show(BuildContext context, String currentEmail) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ChangeEmailDialog(currentEmail: currentEmail),
    );
  }

  @override
  ConsumerState<ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends ConsumerState<ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newEmailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _newEmailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _newEmailController.text.trim();
    final password = _passwordController.text;

    if (newEmail.toLowerCase() == widget.currentEmail.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email mới phải khác email hiện tại.')),
      );
      return;
    }

    final success = await ref
        .read(editProfileNotifierProvider.notifier)
        .updateEmail(newEmail: newEmail, currentPassword: password);

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
      child: Padding(
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
                      LucideIcons.mail,
                      color: AppColors.primary,
                      size: 18.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Thay đổi địa chỉ Email',
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
                'Để bảo mật, vui lòng nhập mật khẩu hiện tại trước khi cập nhật email mới.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.slate500,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Current email badge
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Text(
                      'Email hiện tại: ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.currentEmail,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slate800,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // New Email field
              AppTextField(
                controller: _newEmailController,
                label: 'Địa chỉ Email mới',
                placeholder: 'vidu@gmail.com',
                prefixIcon: const Icon(LucideIcons.mailCheck),
                keyboardType: TextInputType.emailAddress,
                validator: InputValidators.validateEmail,
              ),
              SizedBox(height: 14.h),

              // Current password
              AppTextField(
                controller: _passwordController,
                label: 'Mật khẩu hiện tại',
                placeholder: 'Nhập mật khẩu để xác nhận',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(LucideIcons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18.r,
                    color: AppColors.slate400,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (val) =>
                    InputValidators.validateRequired(val, 'Mật khẩu hiện tại'),
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
                      label: 'Cập nhật',
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
