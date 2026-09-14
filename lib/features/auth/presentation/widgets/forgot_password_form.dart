import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';

class ForgotPasswordForm extends StatelessWidget {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final TextEditingController emailController;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;

  const ForgotPasswordForm({
    super.key,
    required this.isLoading,
    required this.isSuccess,
    this.errorMessage,
    required this.emailController,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: isSuccess ? _buildSuccessView() : _buildInputView(),
    );
  }

  Widget _buildSuccessView() {
    final email = emailController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.emerald100,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              LucideIcons.mailCheck,
              size: 34,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kiểm tra hộp thư email',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.slate800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (email.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              email,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Chúng tôi đã gửi liên kết khôi phục mật khẩu đến email của bạn. Vui lòng kiểm tra hộp thư đến (kể cả thư mục Spam) và nhấp vào liên kết để tạo mật khẩu mới.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.slate500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        SecondaryButton(text: 'Quay lại đăng nhập', onPressed: onBackToLogin),
      ],
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quên mật khẩu',
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.slate800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Vui lòng nhập địa chỉ email đã đăng ký để nhận liên kết khôi phục mật khẩu.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.slate400),
        ),
        const SizedBox(height: 20),

        // Error Banner
        AppErrorBanner(message: errorMessage),

        // Reusable AppTextField
        AppTextField(
          label: 'Địa chỉ email',
          placeholder: 'name@example.com',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: isLoading ? null : (_) => onSubmit(),
          enabled: !isLoading,
          borderRadius: 12.0,
          prefixIcon: const Icon(
            LucideIcons.mail,
            size: 20,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 20),

        // Reusable PrimaryButton
        PrimaryButton(
          text: 'Gửi liên kết đặt lại',
          isLoading: isLoading,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 12),

        // Reusable SecondaryButton
        SecondaryButton(
          text: 'Quay lại đăng nhập',
          onPressed: isLoading ? null : onBackToLogin,
        ),
      ],
    );
  }
}
