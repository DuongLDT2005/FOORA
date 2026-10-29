import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../../inventory/domain/entities/storage_location.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../inventory/presentation/widgets/date_field_picker_tile.dart';
import '../../../inventory/presentation/widgets/item_category_location_selectors.dart';
import '../../domain/entities/import_shopping_item_request.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/usecases/import_shopping_items_to_inventory.dart';
import '../providers/shopping_providers.dart';
import 'shopping_item_tile.dart';

/// The generic category is not accepted by the backend, so expiry always
/// comes from a real shelf-life rule.
const String _otherCategoryId = 'other';

class _ImportRow {
  final ShoppingItem item;
  final TextEditingController quantity;
  bool isSelected = true;
  String locationId = StorageLocationCode.fridge.name;
  String? categoryId;

  _ImportRow(this.item)
    : quantity = TextEditingController(
        text: formatShoppingQuantity(item.quantity),
      );

  double? get parsedQuantity =>
      double.tryParse(quantity.text.trim().replaceAll(',', '.'));
}

/// Confirms purchased items before they are moved into the fridge
/// (PLAN_01 §5.5). Expiry is computed by the backend, not entered here.
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
    return BottomSheetHelper.show<void>(
      context,
      title: 'Nhập vào tủ lạnh',
      maxHeightFactor: 0.9,
      child: BatchImportInventorySheet(
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
  late final List<_ImportRow> _rows;
  DateTime _purchaseDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.candidateItems
        .take(maxShoppingImportItems)
        .map(_ImportRow.new)
        .toList();
    for (final row in _rows) {
      row.quantity.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.quantity.dispose();
    }
    super.dispose();
  }

  static bool _isSelectable(FoodCategory c) =>
      c.id != _otherCategoryId && c.code.toLowerCase() != _otherCategoryId;

  List<_ImportRow> get _selected => _rows.where((r) => r.isSelected).toList();

  bool get _canSubmit =>
      _selected.isNotEmpty &&
      _selected.every(
        (r) => r.categoryId != null && (r.parsedQuantity ?? 0) > 0,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final requests = [
      for (final row in _selected)
        ImportShoppingItemRequest(
          shoppingItemId: row.item.id,
          storageLocation: StorageLocationCode.values.byName(row.locationId),
          categoryId: row.categoryId!,
          actualQuantity: row.parsedQuantity!,
          purchaseDate: _purchaseDate,
        ),
    ];

    setState(() => _isSaving = true);
    try {
      final count = await ref
          .read(shoppingControllerProvider)
          .importToInventory(widget.listId, requests);
      if (!mounted) return;
      ToastHelper.show(context, 'Đã thêm $count món vào tủ lạnh');
      Navigator.of(context).pop();
    } on ResourceExhaustedFailure catch (e) {
      if (!mounted) return;
      final upgrade = await DialogHelper.showConfirmDialog(
        context,
        title: 'Đã đạt giới hạn thực phẩm',
        message: e.message,
        confirmText: 'Nâng cấp',
        icon: Icons.workspace_premium_outlined,
      );
      if (upgrade == true && mounted) context.push(AppRouteNames.membership);
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, shoppingErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final locationsAsync = ref.watch(storageLocationsProvider);
    final categories = (categoriesAsync.valueOrNull ?? const <FoodCategory>[])
        .where(_isSelectable)
        .toList();
    final locations = (locationsAsync.valueOrNull ?? const <StorageLocation>[])
        .where((l) => StorageLocationCode.values.any((c) => c.name == l.id))
        .toList();
    final isLoadingMetadata =
        categoriesAsync.isLoading || locationsAsync.isLoading;

    // Pre-select the category the item already had, when it is selectable.
    for (final row in _rows) {
      row.categoryId ??= categories
          .where((c) => c.id == row.item.categoryId)
          .firstOrNull
          ?.id;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chọn món, số lượng thực mua, danh mục và ngăn bảo quản. Hạn '
              'dùng được tính tự động.',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamilySans,
                fontSize: 13.sp,
                color: AppColors.slate500,
              ),
            ),
            if (widget.candidateItems.length > maxShoppingImportItems) ...[
              SizedBox(height: 8.h),
              Text(
                'Mỗi lần nhập tối đa $maxShoppingImportItems món.',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilySans,
                  fontSize: 12.sp,
                  color: AppColors.amber700,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            DateFieldPickerTile(
              label: 'NGÀY MUA',
              date: _purchaseDate,
              onTap: _pickDate,
            ),
            SizedBox(height: 16.h),
            for (final row in _rows)
              _buildRow(row, categories, locations, isLoadingMetadata),
            SizedBox(height: 8.h),
            PrimaryButton(
              text: 'Thêm vào tủ (${_selected.length})',
              isLoading: _isSaving,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    _ImportRow row,
    List<FoodCategory> categories,
    List<StorageLocation> locations,
    bool isLoadingMetadata,
  ) {
    final radius = BorderRadius.circular(14.r);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: row.isSelected
            ? AppColors.surfaceContainerLowest
            : AppColors.slate100,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: row.isSelected ? AppColors.primary : AppColors.slate200,
            width: row.isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: radius,
                onTap: () => setState(() => row.isSelected = !row.isSelected),
                child: Row(
                  children: [
                    ShoppingCheckbox(checked: row.isSelected),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        row.item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (row.isSelected) ...[
                SizedBox(height: 14.h),
                AppTextField(
                  label: 'Số lượng thực mua',
                  isRequired: true,
                  controller: row.quantity,
                  fillColor: AppColors.surfaceContainerLowest,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffixIcon: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.only(right: 16.w),
                      child: Text(
                        row.item.unit,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                ItemCategoryLocationSelectors(
                  isLoading: isLoadingMetadata,
                  categories: categories,
                  storageLocations: locations,
                  selectedCategoryId: row.categoryId ?? '',
                  selectedStorageLocationId: row.locationId,
                  categoryPlaceholder: 'Chọn danh mục',
                  onCategoryChanged: (id) =>
                      setState(() => row.categoryId = id),
                  onLocationChanged: (id) =>
                      setState(() => row.locationId = id),
                  onRetry: () {
                    ref.invalidate(foodCategoriesProvider);
                    ref.invalidate(storageLocationsProvider);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
