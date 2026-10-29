import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';

class ShoppingListCard extends ConsumerWidget {
  final ShoppingList shoppingList;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const ShoppingListCard({
    super.key,
    required this.shoppingList,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (purchasedCount, totalCount) =
        ref.watch(shoppingListProgressProvider(shoppingList.id));

    final progressRatio = totalCount > 0 ? (purchasedCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final isCompleted = totalCount > 0 && purchasedCount == totalCount;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isCompleted ? AppColors.primary.withValues(alpha: 0.3) : AppColors.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Container
                    Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.slate100,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        isCompleted ? LucideIcons.checkCheck : LucideIcons.shoppingBag,
                        color: isCompleted ? AppColors.primary : AppColors.slate600,
                        size: 22.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Title & Note
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shoppingList.name,
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamilyHeadline,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shoppingList.note != null && shoppingList.note!.isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              shoppingList.note!,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.slate500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Text(
                            DateFormatter.timeAgo(shoppingList.updatedAt),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        LucideIcons.ellipsisVertical,
                        size: 18.r,
                        color: AppColors.slate400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      onSelected: (value) {
                        if (value == 'rename') {
                          onRename();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(LucideIcons.pencil, size: 16, color: AppColors.slate600),
                              SizedBox(width: 8),
                              Text('Đổi tên'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(LucideIcons.trash2, size: 16, color: AppColors.red500),
                              SizedBox(width: 8),
                              Text('Xóa danh sách', style: TextStyle(color: AppColors.red500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                // Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 6.h,
                          backgroundColor: AppColors.slate100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? AppColors.primary : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      '$purchasedCount/$totalCount món',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? AppColors.primary : AppColors.slate600,
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
