import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/inventory_list_provider.dart';
import '../providers/inventory_provider.dart';

class CategoryFilterList extends ConsumerWidget {
  const CategoryFilterList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final selectedCategoryId = ref.watch(
      inventoryListNotifierProvider.select((s) => s.selectedCategoryId),
    );

    return categoriesAsync.when(
      data: (categories) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              _buildCategoryChip(
                context: context,
                ref: ref,
                id: 'all',
                label: 'Tất cả',
                icon: LucideIcons.layoutGrid,
                isSelected: selectedCategoryId == 'all',
              ),
              ...categories
                  .where((c) => c.isActive)
                  .map(
                    (cat) => Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: _buildCategoryChip(
                        context: context,
                        ref: ref,
                        id: cat.id,
                        label: cat.name,
                        icon: _getIconData(cat.icon),
                        isSelected: selectedCategoryId == cat.id,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        ref
            .read(inventoryListNotifierProvider.notifier)
            .updateCategoryFilter(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.r,
              color: isSelected ? Colors.white : AppColors.slate500,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.replaceAll('lucide-', '')) {
      case 'carrot':
        return LucideIcons.carrot;
      case 'beef':
        return LucideIcons.beef;
      case 'egg':
        return LucideIcons.egg;
      case 'flame':
        return LucideIcons.flame;
      case 'cup-soda':
        return LucideIcons.cupSoda;
      case 'apple':
        return LucideIcons.apple;
      case 'fish':
        return LucideIcons.fish;
      case 'drumstick':
        return LucideIcons.drumstick;
      case 'milk':
        return LucideIcons.milk;
      default:
        return LucideIcons.utensils;
    }
  }
}
