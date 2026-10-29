import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';

enum ShoppingAddMode { manual, voice }

/// Lets the user pick how to add items: typing or speaking.
class AddModeSheet extends StatelessWidget {
  const AddModeSheet({super.key});

  static Future<ShoppingAddMode?> show(BuildContext context) {
    return BottomSheetHelper.show<ShoppingAddMode>(
      context,
      title: 'Thêm món',
      child: const AddModeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _ModeCard(
            mode: ShoppingAddMode.manual,
            icon: LucideIcons.keyboard,
            title: 'Nhập tay',
            subtitle: 'Gõ tên món, số lượng và đơn vị',
          ),
          _ModeCard(
            mode: ShoppingAddMode.voice,
            icon: LucideIcons.mic,
            title: 'Nói',
            subtitle: 'Ví dụ: "2 hộp sữa, 1 kg thịt heo và 6 quả trứng"',
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final ShoppingAddMode mode;
  final IconData icon;
  final String title;
  final String subtitle;

  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14.r);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.slate200),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).pop(mode),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18.r, color: AppColors.primary),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 12.sp,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18.r,
                  color: AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
