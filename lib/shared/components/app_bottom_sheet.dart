import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// AppBottomSheet widget representing a styled modal bottom sheet container
/// with a drag handle, title header, close button, and scrollable content area.
class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final double? maxHeightFactor;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.maxHeightFactor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxAllowedHeight = maxHeightFactor != null
        ? screenHeight * maxHeightFactor!
        : screenHeight - (MediaQuery.of(context).padding.top + 40.h);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxAllowedHeight,
          maxWidth: 520.w, // Ergonomic max width for tablet & web
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  width: 48.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                    left: 20.w,
                    right: 20.w,
                    top: 8.h,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
