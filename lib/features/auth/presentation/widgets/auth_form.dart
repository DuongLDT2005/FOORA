import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_segmented_control.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';

class AuthForm extends StatelessWidget {
  final bool isLoginMode;
  final bool isLoading;
  final bool showPassword;
  final bool showConfirmPassword;
  final String? errorMessage;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final ValueChanged<bool> onToggleMode;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  const AuthForm({
    super.key,
    required this.isLoginMode,
    required this.isLoading,
    required this.showPassword,
    required this.showConfirmPassword,
    this.errorMessage,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onToggleMode,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 20.r,
            spreadRadius: -4.r,
            offset: Offset(0, 10.h),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 32.r,
            spreadRadius: -6.r,
            offset: Offset(0, 16.h),
          ),
        ],
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tab Selection
          AppSegmentedControl<bool>(
            selectedValue: isLoginMode,
            items: const [
              SegmentedItem(value: true, label: 'Đăng nhập'),
              SegmentedItem(value: false, label: 'Đăng ký'),
            ],
            onValueChanged: isLoading ? (_) {} : onToggleMode,
          ),
          SizedBox(height: 20.h),

          // 2. Error message banner
          AppErrorBanner(message: errorMessage),

          // 3. Full Name Input (Register Only)
          if (!isLoginMode) ...[
            AppTextField(
              label: 'Họ và tên',
              placeholder: 'Nguyễn Văn A',
              controller: fullNameController,
              enabled: !isLoading,
              borderRadius: 12.0.r,
              prefixIcon: Icon(
                LucideIcons.user,
                size: 20.r,
                color: AppColors.slate400,
              ),
            ),
            SizedBox(height: 20.h),
          ],

          // 4. Email Input
          AppTextField(
            label: 'Địa chỉ email',
            placeholder: 'name@example.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            borderRadius: 12.0.r,
            prefixIcon: Icon(
              LucideIcons.mail,
              size: 20.r,
              color: AppColors.slate400,
            ),
          ),
          SizedBox(height: 20.h),

          // 5. Password Input
          AppTextField(
            label: 'Mật khẩu',
            placeholder: '••••••••',
            controller: passwordController,
            obscureText: !showPassword,
            enabled: !isLoading,
            borderRadius: 12.0.r,
            prefixIcon: Icon(
              LucideIcons.lock,
              size: 20.r,
              color: AppColors.slate400,
            ),
            headerTrailing: isLoginMode
                ? GestureDetector(
                    onTap: isLoading ? null : onForgotPassword,
                    child: Text(
                      'Quên mật khẩu?',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 20.r,
                color: AppColors.slate400,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
          ),
          SizedBox(height: 20.h),

          // 6. Confirm Password Input (Register Only - from Stitch)
          if (!isLoginMode) ...[
            AppTextField(
              label: 'Xác nhận mật khẩu',
              placeholder: '••••••••',
              controller: confirmPasswordController,
              obscureText: !showConfirmPassword,
              enabled: !isLoading,
              borderRadius: 12.0.r,
              prefixIcon: Icon(
                LucideIcons.lock,
                size: 20.r,
                color: AppColors.slate400,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  showConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20.r,
                  color: AppColors.slate400,
                ),
                onPressed: onToggleConfirmPasswordVisibility,
              ),
            ),
            SizedBox(height: 24.h),
          ] else ...[
            SizedBox(height: 8.h),
          ],

          // 7. Submit Button
          PrimaryButton(
            text: isLoginMode ? 'Đăng nhập' : 'Tạo tài khoản mới',
            isLoading: isLoading,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}
