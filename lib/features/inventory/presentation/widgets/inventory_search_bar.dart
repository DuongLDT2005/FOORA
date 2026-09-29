import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/inventory_list_provider.dart';
import 'filter_bottom_sheet.dart';

class InventorySearchBar extends ConsumerStatefulWidget {
  const InventorySearchBar({super.key});

  @override
  ConsumerState<InventorySearchBar> createState() => _InventorySearchBarState();
}

class _InventorySearchBarState extends ConsumerState<InventorySearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(
      inventoryListNotifierProvider.select((s) => s.searchQuery),
    );

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44.h, // h-11 = 44px
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _isFocused
                    ? AppColors.primary
                    : AppColors.slate200.withValues(alpha: 0.6),
              ),
              boxShadow: [
                if (_isFocused)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 0,
                    spreadRadius: 2,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: 14.w),
                Icon(LucideIcons.search, size: 16.r, color: AppColors.slate400),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextFormField(
                    focusNode: _focusNode,
                    initialValue: searchQuery,
                    onChanged: (value) {
                      ref
                          .read(inventoryListNotifierProvider.notifier)
                          .updateSearchQuery(value);
                    },
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.slate800,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm nguyên liệu...',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.slate400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(inventoryListNotifierProvider.notifier)
                          .updateSearchQuery('');
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Icon(
                        LucideIcons.x,
                        size: 16.r,
                        color: AppColors.slate400,
                      ),
                    ),
                  )
                else
                  SizedBox(width: 16.w),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.w),
        // Filter Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              FilterBottomSheet.show(context);
            },
            borderRadius: BorderRadius.circular(12.r),
            hoverColor: AppColors.slate50,
            child: Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.slate200.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.slidersHorizontal,
                size: 20.r,
                color: AppColors.slate600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
