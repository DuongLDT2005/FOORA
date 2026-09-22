import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/inventory_list_provider.dart';

class InventoryStatsBanner extends ConsumerWidget {
  const InventoryStatsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringSoonCount = ref.watch(
      inventoryListNotifierProvider.select((s) => s.expiringSoonCount),
    );
    final expiredCount = ref.watch(
      inventoryListNotifierProvider.select((s) => s.expiredCount),
    );

    if (expiringSoonCount == 0 && expiredCount == 0) {
      return const SizedBox.shrink(); // Hide if nothing to warn
    }

    return GestureDetector(
      onTap: () {
        context.push(AppRouteNames.expirationManagement);
      },
      child: Container(
        padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.emerald50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.emerald100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.emerald100,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              LucideIcons.sparkles,
              color: AppColors.emerald700,
              size: 16.r,
            ), // animate pulse could be added with an AnimationController
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi ý tủ lạnh thông minh',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                    color: AppColors.emerald800,
                  ),
                ),
                SizedBox(height: 4.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.sp,
                      color: AppColors.slate500,
                      height: 1.5,
                    ),
                    children: _buildMessageTextSpans(
                      expiringSoonCount,
                      expiredCount,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  List<TextSpan> _buildMessageTextSpans(
    int expiringSoon,
    int expired,
  ) {
    List<TextSpan> spans = [const TextSpan(text: 'Tủ đang có ')];

    if (expiringSoon > 0) {
      spans.add(
        TextSpan(
          text: '$expiringSoon nguyên liệu',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.amber700,
          ),
        ),
      );
      spans.add(const TextSpan(text: ' cận ngày hết hạn'));
    }

    if (expiringSoon > 0 && expired > 0) {
      spans.add(const TextSpan(text: ' và '));
    }

    if (expired > 0) {
      spans.add(
        TextSpan(
          text: '$expired nguyên liệu',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.red700,
          ),
        ),
      );
      spans.add(const TextSpan(text: ' đã quá hạn'));
    }

    spans.add(const TextSpan(text: '. Bấm chọn '));
    spans.add(
      const TextSpan(
        text: 'Quản lý hạn dùng',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    spans.add(const TextSpan(text: ' để phân loại chuẩn xác.'));

    return spans;
  }
}
