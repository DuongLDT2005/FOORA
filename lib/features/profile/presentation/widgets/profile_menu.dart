import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
            child: Text(
              title!,
              style: AppTextStyles.labelSmall.copyWith(
                fontFamily: AppTextStyles.fontFamilyHeadline,
                fontSize: 12.sp,
                color: AppColors.slate400,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.slate100),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.025),
                blurRadius: 8.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.iconBgColor,
    this.isDestructive = false,
    this.showDivider = true,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool isDestructive;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isDestructive
        ? AppColors.red600
        : (iconColor ?? AppColors.primary);
    final background = isDestructive
        ? AppColors.red50
        : (iconBgColor ?? AppColors.emerald50);

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 22.r, color: foreground),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontFamily: AppTextStyles.fontFamilyHeadline,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isDestructive
                              ? AppColors.red600
                              : AppColors.slate700,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.slate400,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18.r,
                      color: AppColors.slate300,
                    ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: EdgeInsets.only(left: 72.w),
              child: const Divider(height: 1, color: AppColors.slate50),
            ),
        ],
      ),
    );
  }
}
