import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import 'open_google_maps_button.dart';

class LocationPermissionView extends StatelessWidget {
  const LocationPermissionView({
    super.key,
    required this.errorCode,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationErrorCode errorCode;
  final VoidCallback onRetry;

  /// Opens system settings; the page retries when the app resumes.
  final VoidCallback onOpenSettings;

  bool get _needsSettings =>
      errorCode == LocationErrorCode.serviceDisabled ||
      errorCode == LocationErrorCode.deniedForever;

  @override
  Widget build(BuildContext context) {
    final title = switch (errorCode) {
      LocationErrorCode.serviceDisabled => 'Hãy bật định vị',
      LocationErrorCode.denied => 'Cho phép dùng vị trí',
      LocationErrorCode.deniedForever => 'Cần quyền vị trí',
      LocationErrorCode.timeout => 'Chưa lấy được vị trí',
    };
    final message = switch (errorCode) {
      LocationErrorCode.serviceDisabled =>
        'FOORA cần GPS để tìm các cửa hàng quanh bạn.',
      LocationErrorCode.denied =>
        'Vị trí chỉ được dùng khi bạn đang mở bản đồ cửa hàng.',
      LocationErrorCode.deniedForever =>
        'Mở cài đặt ứng dụng để cấp lại quyền vị trí cho FOORA.',
      LocationErrorCode.timeout => 'Kiểm tra GPS hoặc kết nối rồi thử lại.',
    };
    final action = switch (errorCode) {
      LocationErrorCode.serviceDisabled => 'Bật định vị',
      LocationErrorCode.denied => 'Cho phép',
      LocationErrorCode.deniedForever => 'Mở cài đặt',
      LocationErrorCode.timeout => 'Thử lại',
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mapPinned, size: 48.r, color: AppColors.primary),
            SizedBox(height: 16.h),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.slate800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.slate600,
              ),
            ),
            SizedBox(height: 20.h),
            PrimaryButton(
              text: action,
              onPressed: _needsSettings ? onOpenSettings : onRetry,
            ),
            if (_needsSettings)
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            if (errorCode == LocationErrorCode.timeout)
              const OpenGoogleMapsButton(),
          ],
        ),
      ),
    );
  }
}
