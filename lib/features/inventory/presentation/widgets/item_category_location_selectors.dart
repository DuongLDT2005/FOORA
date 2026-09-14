import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_shimmer.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/storage_location.dart';

/// Component handling Category and Storage Location selection for Item Form
class ItemCategoryLocationSelectors extends StatelessWidget {
  final bool isLoading;
  final List<FoodCategory> categories;
  final List<StorageLocation> storageLocations;
  final String selectedCategoryId;
  final String selectedStorageLocationId;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback? onRetry;

  const ItemCategoryLocationSelectors({
    super.key,
    required this.isLoading,
    required this.categories,
    required this.storageLocations,
    required this.selectedCategoryId,
    required this.selectedStorageLocationId,
    required this.onCategoryChanged,
    required this.onLocationChanged,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Loading metadata (Shimmer)
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DANH MỤC *',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.slate600,
              fontWeight: FontWeight.w700,
              fontSize: 11.sp,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 6.h),
          AppShimmer.box(width: double.infinity, height: 48.h, borderRadius: 16.r),
          SizedBox(height: 16.h),
          Text(
            'VỊ TRÍ BẢO QUẢN *',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.slate600,
              fontWeight: FontWeight.w700,
              fontSize: 11.sp,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 6.h),
          AppShimmer.box(width: double.infinity, height: 48.h, borderRadius: 16.r),
          SizedBox(height: 16.h),
        ],
      );
    }

    // 2. No data (Not seeded yet or network error)
    if (categories.isEmpty || storageLocations.isEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20.r, color: AppColors.slate500),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Không tải được danh mục hoặc vị trí bảo quản.',
                style: TextStyle(fontSize: 12.sp, color: AppColors.slate600),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text('Thử lại', style: TextStyle(fontSize: 12.sp)),
              ),
          ],
        ),
      );
    }

    // 3. Display dropdown & selector
    final activeCatId = categories.any((c) => c.id == selectedCategoryId)
        ? selectedCategoryId
        : categories.first.id;

    final activeLocId =
        storageLocations.any((l) => l.id == selectedStorageLocationId)
        ? selectedStorageLocationId
        : storageLocations.first.id;

    final selectedCat = categories.cast<FoodCategory>().firstWhere(
      (c) => c.id == activeCatId,
      orElse: () => categories.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CATEGORY (Opens BottomSheetHelper selector)
        RichText(
          text: TextSpan(
            text: 'DANH MỤC',
            style: AppTextStyles.inputLabel.copyWith(
              color: AppColors.slate600,
              fontSize: 12.sp,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.red500),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        InkWell(
          onTap: () {
            BottomSheetHelper.showSelect<String>(
              context,
              title: 'Danh mục thực phẩm',
              maxHeightFactor: 0.6,
              selectedValue: activeCatId,
              onSelected: onCategoryChanged,
              options: categories.map((cat) {
                return SelectOption<String>(
                  value: cat.id,
                  label: cat.name,
                  leading: Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: cat.id == activeCatId
                          ? AppColors.primary
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(cat.icon),
                        size: 18.r,
                        color: cat.id == activeCatId
                            ? Colors.white
                            : AppColors.slate600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(selectedCat.icon),
                      size: 20.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      selectedCat.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                        color: AppColors.slate800,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20.r,
                  color: AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // 2. STORAGE LOCATION (1-touch segmented choice pills)
        RichText(
          text: TextSpan(
            text: 'VỊ TRÍ BẢO QUẢN',
            style: AppTextStyles.inputLabel.copyWith(
              color: AppColors.slate600,
              fontSize: 12.sp,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.red500),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: storageLocations.map((loc) {
            final isSelected = loc.id == activeLocId;
            final isFridge = loc.id.toLowerCase().contains('fridge');

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: loc == storageLocations.last ? 0 : 10.w,
                ),
                child: InkWell(
                  onTap: () => onLocationChanged(loc.id),
                  borderRadius: BorderRadius.circular(16.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.slate100,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              const BoxShadow(
                                color: AppColors.primary,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFridge
                              ? LucideIcons.thermometer
                              : LucideIcons.snowflake,
                          size: 18.r,
                          color: isSelected ? Colors.white : AppColors.slate500,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          loc.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14.sp,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.slate700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'lucide-carrot':
        return LucideIcons.carrot;
      case 'lucide-apple':
        return LucideIcons.apple;
      case 'lucide-beef':
        return LucideIcons.beef;
      case 'lucide-fish':
        return LucideIcons.fish;
      case 'lucide-egg':
        return LucideIcons.egg;
      case 'lucide-wheat':
        return LucideIcons.wheat;
      case 'lucide-flask-conical':
        return LucideIcons.flaskConical;
      case 'lucide-cup-soda':
        return LucideIcons.cupSoda;
      case 'lucide-snowflake':
        return LucideIcons.snowflake;
      case 'lucide-package':
        return LucideIcons.package;
      default:
        return LucideIcons.utensils;
    }
  }
}
