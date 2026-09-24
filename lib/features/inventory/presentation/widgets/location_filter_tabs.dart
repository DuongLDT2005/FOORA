import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/inventory_list_provider.dart';

class LocationFilterTabs extends ConsumerWidget {
  const LocationFilterTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLocationId = ref.watch(
      inventoryListNotifierProvider.select((state) => state.selectedLocationId),
    );

    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: AppColors.slate100.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.slate200.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _buildTab(
            context: context,
            ref: ref,
            id: 'all',
            label: 'Tất cả',
            icon: LucideIcons.layoutGrid,
            isActive: selectedLocationId == 'all',
            activeColor: AppColors.slate800,
          ),
          _buildTab(
            context: context,
            ref: ref,
            id: 'fridge',
            label: 'Ngăn mát',
            icon: LucideIcons.thermometer, // using thermometer since LucideIcons doesn't have refrigerator directly without checking
            isActive: selectedLocationId == 'fridge',
            activeColor: AppColors.emerald500,
            activeLabelColor: AppColors.emerald800,
          ),
          _buildTab(
            context: context,
            ref: ref,
            id: 'freezer',
            label: 'Ngăn đông',
            icon: LucideIcons.snowflake,
            isActive: selectedLocationId == 'freezer',
            activeColor: const Color(0xFF06B6D4), // Cyan-500
            activeLabelColor: const Color(0xFF0891B2), // Cyan-600
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    Color? activeLabelColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref
              .read(inventoryListNotifierProvider.notifier)
              .updateLocationFilter(id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
            border: Border.all(
              color: isActive
                  ? AppColors.slate200.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.r,
                color: isActive ? activeColor : AppColors.slate400,
              ),
              SizedBox(width: 6.w),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isActive
                      ? (activeLabelColor ?? AppColors.slate800)
                      : AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
