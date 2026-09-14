import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SocialLoginButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onGoogleSignIn;

  const SocialLoginButtons({
    super.key,
    this.isLoading = false,
    this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColors.emerald900.withValues(alpha: 0.2),
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'HOẶC TIẾP TỤC VỚI',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.emerald800.withValues(alpha: 0.6),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.emerald900.withValues(alpha: 0.2),
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Center(
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.slate200, width: 1),
            ),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isLoading ? null : onGoogleSignIn,
              child: Container(
                width: 52.r,
                height: 52.r,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/google_logo.png',
                  width: 22.r,
                  height: 22.r,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.g_mobiledata,
                    size: 28.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Bằng cách tiếp tục, bạn đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của chúng tôi.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.sp,
              color: AppColors.slate400,
            ),
          ),
        ),
      ],
    );
  }
}
