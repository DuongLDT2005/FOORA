import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Upper-case section label, same style as the household page sections.
class ShoppingSectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const ShoppingSectionTitle({super.key, required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(
        count == null ? title.toUpperCase() : '${title.toUpperCase()} ($count)',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamilySans,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.slate400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Translucent white button for the right side of [AppHeader], matching its
/// built-in actions.
class ShoppingHeaderMenuButton<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T> onSelected;

  const ShoppingHeaderMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12.r),
      child: PopupMenuButton<T>(
        tooltip: 'Tùy chọn',
        itemBuilder: itemBuilder,
        onSelected: onSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Icon(
            Icons.more_vert_rounded,
            size: 20.r,
            color: AppColors.surfaceContainerLowest,
          ),
        ),
      ),
    );
  }
}
