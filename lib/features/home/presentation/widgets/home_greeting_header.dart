import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../household/presentation/widgets/household_switch_bottom_sheet.dart';

/// Greeting header at the top of the Home screen (user name + household switcher + live status dot).
class HomeGreetingHeader extends StatelessWidget {
  final String firstName;
  final String? householdName;

  const HomeGreetingHeader({
    super.key,
    required this.firstName,
    this.householdName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $firstName! 👋',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilyHeadline,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900, // font-extrabold/black
                  color: AppColors.slate800,
                  letterSpacing: -0.5,
                ),
              ),
              if (householdName != null && householdName!.isNotEmpty) ...[
                // Ink feedback + vertical padding give the small label a
                // finger-sized touch target without changing the layout much.
                InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () => HouseholdSwitchBottomSheet.show(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.home,
                          size: 13.r,
                          color: AppColors.emerald700,
                        ),
                        SizedBox(width: 4.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 160.w),
                          child: Text(
                            householdName!,
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamilySans,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 13.r,
                          color: AppColors.emerald700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              children: [
                // Pulse dot
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Thời gian thực',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700, // font-bold
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
