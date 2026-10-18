import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';

/// Full-screen card shown when the monthly receipt-scan quota is used up.
class QuotaExceededOverlay extends StatelessWidget {
  const QuotaExceededOverlay({
    super.key,
    required this.scansUsed,
    required this.scanLimit,
  });

  final int scansUsed;
  final int scanLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440.w),
          child: Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24.r,
                  offset: Offset(0, 8.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: const BoxDecoration(
                    color: AppColors.amber100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.crown,
                    size: 32.r,
                    color: AppColors.amber500,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'Hết lượt quét hóa đơn',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Bạn đã sử dụng hết $scansUsed/$scanLimit lượt quét hóa đơn AI miễn phí trong tháng này. Hãy nâng cấp gói Premium để tận hưởng lượt quét không giới hạn!',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.slate600,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Để sau',
                        onPressed: () {
                          context.go(AppRouteNames.home);
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: PrimaryButton(
                        text: 'Nâng cấp',
                        onPressed: () {
                          context.push(AppRouteNames.membership);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen progress card shown while the receipt is parsed by AI.
class ScanProcessingOverlay extends StatelessWidget {
  const ScanProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36.r,
                  height: 36.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Đang phân tích hóa đơn bằng AI...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    color: AppColors.slate800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Tự động bóc tách tên món, số lượng và đơn vị',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.slate500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
