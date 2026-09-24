import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_bottom_sheet.dart';
import '../providers/inventory_list_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      barrierDismissible: true,
      barrierLabel: 'Filter',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: FilterBottomSheet(),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10.0 * anim1.value,
                  sigmaY: 10.0 * anim1.value,
                ),
                child: const SizedBox(),
              ),
            ),
            SlideTransition(position: slideAnim, child: child),
          ],
        );
      },
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late InventorySortOption _selectedSort;
  late InventoryStatusFilter _selectedStatus;

  @override
  void initState() {
    super.initState();
    final state = ref.read(inventoryListNotifierProvider);
    _selectedSort = state.sortOption;
    _selectedStatus = state.statusFilter;
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Sắp xếp & Lọc',
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final notifier = ref.read(inventoryListNotifierProvider.notifier);
            notifier.updateSortOption(_selectedSort);
            notifier.updateStatusFilter(_selectedStatus);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 2,
          ),
          child: Text(
            'Áp dụng',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort Options
          Text(
            'SẮP XẾP THEO',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12.sp, // ~text-sm
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
              letterSpacing: 1.2,
            ),
          ),
          RadioGroup<InventorySortOption>(
            groupValue: _selectedSort,
            onChanged: (v) {
              if (v != null) setState(() => _selectedSort = v);
            },
            child: Column(
              children: [
                _buildSortRadio(
                  value: InventorySortOption.newest,
                  label: 'Mới nhất',
                  icon: LucideIcons.clock,
                ),
                SizedBox(height: 8.h),
                _buildSortRadio(
                  value: InventorySortOption.closestExpiry,
                  label: 'Hạn dùng (Gần nhất)',
                  icon: LucideIcons.calendarClock,
                ),
                SizedBox(height: 8.h),
                _buildSortRadio(
                  value: InventorySortOption.nameAsc,
                  label: 'Tên (A-Z)',
                  icon: LucideIcons.arrowDownAZ,
                ),
                SizedBox(height: 8.h),
                _buildSortRadio(
                  value: InventorySortOption.quantityDesc,
                  label: 'Lượng còn lại',
                  icon: LucideIcons.pieChart,
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Status Filter
          Text(
            'TRẠNG THÁI',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildStatusChip(
                value: InventoryStatusFilter.all,
                label: 'Tất cả',
              ),
              _buildStatusChip(
                value: InventoryStatusFilter.expiringSoon,
                label: 'Sắp hết hạn',
              ),
              _buildStatusChip(
                value: InventoryStatusFilter.expired,
                label: 'Đã hết hạn',
              ),
              _buildStatusChip(
                value: InventoryStatusFilter.lowQuantity,
                label: 'Sắp hết lượng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortRadio({
    required InventorySortOption value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedSort == value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedSort = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.slate100,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                size: 16.r,
                color: isSelected ? AppColors.primary : AppColors.slate500,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.slate800 : AppColors.slate700,
                ),
              ),
            ),
            Radio<InventorySortOption>(
              value: value,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required InventoryStatusFilter value,
    required String label,
  }) {
    final isSelected = _selectedStatus == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
