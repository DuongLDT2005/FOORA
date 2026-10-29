import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/shopping_item.dart';
import '../providers/shopping_providers.dart';

class _ImportItemRowState {
  final ShoppingItem item;
  bool isSelected;
  double quantity;
  String locationId; // 'fridge' or 'freezer'
  String? categoryId;

  _ImportItemRowState({
    required this.item,
    this.isSelected = true,
    required this.quantity,
    this.locationId = 'fridge',
    this.categoryId,
  });
}

class BatchImportInventorySheet extends ConsumerStatefulWidget {
  final String listId;
  final List<ShoppingItem> candidateItems;

  const BatchImportInventorySheet({
    super.key,
    required this.listId,
    required this.candidateItems,
  });

  static Future<void> show(
    BuildContext context, {
    required String listId,
    required List<ShoppingItem> candidateItems,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatchImportInventorySheet(
        listId: listId,
        candidateItems: candidateItems,
      ),
    );
  }

  @override
  ConsumerState<BatchImportInventorySheet> createState() =>
      _BatchImportInventorySheetState();
}

class _BatchImportInventorySheetState
    extends ConsumerState<BatchImportInventorySheet> {
  late List<_ImportItemRowState> _rowStates;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rowStates = widget.candidateItems.map((item) {
      return _ImportItemRowState(
        item: item,
        quantity: item.quantity,
        locationId: 'fridge',
      );
    }).toList();
  }

  static String _resolveDefaultCategoryId(List<FoodCategory> categories) {
    if (categories.isEmpty) return 'dry';
    for (final c in categories) {
      if (c.code.toLowerCase() != 'other') {
        return c.id;
      }
    }
    return categories.first.id;
  }

  Future<void> _submit(List<FoodCategory> categories) async {
    final selectedRows = _rowStates.where((r) => r.isSelected).toList();
    if (selectedRows.isEmpty) {
      ToastHelper.show(context, 'Vui lòng chọn ít nhất 1 món để nhập kho', isError: true);
      return;
    }

    // Default category ID if not specified or invalid
    final String fallbackCatId = _resolveDefaultCategoryId(categories);

    // Build payload with explicit types
    final List<Map<String, dynamic>> itemsPayload = selectedRows.map((row) {
      final bool hasValidCategory = row.categoryId != null &&
          row.categoryId!.isNotEmpty &&
          row.categoryId != 'other' &&
          categories.any((c) => c.id == row.categoryId);

      final String catId = hasValidCategory ? row.categoryId! : fallbackCatId;

      return <String, dynamic>{
        'shoppingItemId': row.item.id,
        'name': row.item.name,
        'quantity': row.quantity,
        'unit': row.item.unit,
        'locationId': row.locationId,
        'categoryId': catId,
        if (row.item.foodId != null) 'foodId': row.item.foodId,
      };
    }).toList();

    setState(() => _isLoading = true);

    try {
      final count = await ref
          .read(shoppingControllerProvider.notifier)
          .importShoppingItemsToInventory(
            listId: widget.listId,
            items: itemsPayload,
          );

      if (mounted) {
        ToastHelper.show(context, 'Đã nhập thành công $count món vào tủ lạnh!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Lỗi nhập kho: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final List<FoodCategory> categories =
        categoriesAsync.valueOrNull ?? const <FoodCategory>[];
    final String defaultCatId = _resolveDefaultCategoryId(categories);

    final selectedCount = _rowStates.where((r) => r.isSelected).length;

    return Container(
      height: 0.85.sh,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập thực phẩm vào kho',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamilyHeadline,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Chọn vị trí và danh mục cho các món đã mua',
                    style: TextStyle(fontSize: 12.sp, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(LucideIcons.x, size: 20.r, color: AppColors.slate500),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Select All Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chọn $selectedCount / ${_rowStates.length} món',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {
                  final allSelected = selectedCount == _rowStates.length;
                  setState(() {
                    for (final r in _rowStates) {
                      r.isSelected = !allSelected;
                    }
                  });
                },
                child: Text(
                  selectedCount == _rowStates.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          SizedBox(height: 8.h),

          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: _rowStates.length,
              itemBuilder: (context, index) {
                final row = _rowStates[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: row.isSelected ? AppColors.primary : AppColors.slate300,
                      width: row.isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item header with Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: row.isSelected,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            onChanged: (val) {
                              setState(() => row.isSelected = val ?? false);
                            },
                          ),
                          Expanded(
                            child: Text(
                              row.item.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: row.isSelected ? Colors.black : Colors.black54,
                              ),
                            ),
                          ),
                          Text(
                            '${row.quantity} ${row.item.unit}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      if (row.isSelected) ...[
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            // Location Selector: Fridge / Freezer
                            Expanded(
                              flex: 5,
                              child: SegmentedButton<String>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: 'fridge',
                                    label: Text(
                                      'Mát',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: row.locationId == 'fridge' ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    icon: Icon(
                                      LucideIcons.snowflake,
                                      size: 14.r,
                                      color: row.locationId == 'fridge' ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: 'freezer',
                                    label: Text(
                                      'Đông',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: row.locationId == 'freezer' ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    icon: Icon(
                                      LucideIcons.flame,
                                      size: 14.r,
                                      color: row.locationId == 'freezer' ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                                selected: {row.locationId},
                                onSelectionChanged: (newVal) {
                                  setState(() => row.locationId = newVal.first);
                                },
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: AppColors.primary,
                                  selectedForegroundColor: Colors.white,
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            // Category Selector
                            Builder(
                              builder: (context) {
                                final String? selectedCategoryValue = categories.any((c) => c.id == row.categoryId)
                                    ? row.categoryId
                                    : (categories.isNotEmpty ? defaultCatId : null);

                                return Expanded(
                                  flex: 5,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFDF8),
                                      border: Border.all(color: AppColors.primary, width: 1.2),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedCategoryValue,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFFFFFDF8),
                                        icon: Icon(LucideIcons.chevronDown, size: 16.r, color: AppColors.primary),
                                        style: TextStyle(fontSize: 12.sp, color: Colors.black, fontWeight: FontWeight.bold),
                                        selectedItemBuilder: (context) {
                                          return categories.map((cat) {
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                cat.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          }).toList();
                                        },
                                        items: categories.map((cat) {
                                          final isSelected = cat.id == selectedCategoryValue;
                                          return DropdownMenuItem<String>(
                                            value: cat.id,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: isSelected ? AppColors.primary : Colors.transparent,
                                                borderRadius: BorderRadius.circular(6.r),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      cat.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                        color: isSelected ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Icon(LucideIcons.check, size: 14.r, color: Colors.white),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => row.categoryId = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 12.h),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: (_isLoading || selectedCount == 0)
                  ? null
                  : () => _submit(categories),
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : Icon(LucideIcons.packagePlus, size: 18.r),
              label: _isLoading
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Xác nhận nhập kho ($selectedCount món)',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
