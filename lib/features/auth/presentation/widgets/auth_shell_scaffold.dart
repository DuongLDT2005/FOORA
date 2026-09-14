import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AuthShellScaffold extends StatelessWidget {
  final Widget child;

  const AuthShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 450.w, // Phone max width simulator / responsive
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: kIsWeb
                ? BorderRadius.circular(40.r)
                : BorderRadius.zero,
            boxShadow: kIsWeb
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 30.r,
                      offset: Offset(0, 10.h),
                    ),
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.surface],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 16.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 16.h),
                    _buildHeaderLogo(),
                    SizedBox(height: 24.h),
                    child,
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64.r,
          height: 64.r,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald900.withValues(alpha: 0.12),
                blurRadius: 20.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'F',
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'FOORA',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primary,
            fontSize: 28.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Trợ lý quản lý thực phẩm thông minh',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.emerald800.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
