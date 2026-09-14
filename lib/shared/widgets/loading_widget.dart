import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- AppLoadingSpinner ---
class AppLoadingSpinner extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const AppLoadingSpinner({
    super.key,
    this.size = 20.0,
    this.color = Colors.white,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// --- FullScreenLoader ---
class FullScreenLoader extends StatelessWidget {
  final Color backgroundColor;

  const FullScreenLoader({super.key, this.backgroundColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: AppLoadingSpinner(
          size: 40.r,
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

// --- LoadingWidget (General inline loading state) ---
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color color;

  const LoadingWidget({
    super.key,
    this.message,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLoadingSpinner(size: 32.r, color: color, strokeWidth: 3),
            if (message != null) ...[
              SizedBox(height: 16.h),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
