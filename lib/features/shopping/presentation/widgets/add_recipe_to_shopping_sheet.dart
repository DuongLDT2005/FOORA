import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../inventory/presentation/widgets/unit_picker_field.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/usecases/build_recipe_shopping_drafts.dart';
import '../../domain/usecases/parse_voice_shopping_text.dart';
import '../providers/shopping_providers.dart';
import 'shopping_item_tile.dart';

/// Dropdown value that creates a new list instead of using an existing one.
const String _newListValue = '';

/// What [AddRecipeToShoppingSheet] saved, so the caller can link to the list.
typedef RecipeShoppingOutcome = ({
  String listId,
  AddShoppingItemsResult result,
});

/// Adds the missing ingredients of an AI recipe to a shopping list. The user
/// picks the list and the items and can fix amounts; nothing is saved until
/// they confirm (PLAN_04 §5, PLAN_01 §1.2).
class AddRecipeToShoppingSheet extends ConsumerStatefulWidget {
  final String recipeTitle;
  final List<RecipeShoppingIngredient> ingredients;

  const AddRecipeToShoppingSheet({
    super.key,
    required this.recipeTitle,
    required this.ingredients,
  });

  static Future<RecipeShoppingOutcome?> show(
    BuildContext context, {
    required String recipeTitle,
    required List<RecipeShoppingIngredient> ingredients,
  }) {
    return BottomSheetHelper.show<RecipeShoppingOutcome>(
      context,
      title: 'Thêm vào danh sách mua',
      child: AddRecipeToShoppingSheet(
        recipeTitle: recipeTitle,
        ingredients: ingredients,
      ),
    );
  }

  @override
  ConsumerState<AddRecipeToShoppingSheet> createState() =>
      _AddRecipeToShoppingSheetState();
}

class _DraftRow {
  final ShoppingItemDraft draft;
  final TextEditingController quantity;
  String unit;
  bool selected = true;

  _DraftRow(this.draft)
    : unit = draft.unit,
      quantity = TextEditingController(
        text: formatShoppingQuantity(draft.quantity),
      );
}

class _AddRecipeToShoppingSheetState
    extends ConsumerState<AddRecipeToShoppingSheet> {
  late final List<_DraftRow> _rows;
  late final TextEditingController _newListName;

  /// Null until the lists load; [_newListValue] means "create a new list".
  String? _listId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final drafts = const BuildRecipeShoppingDraftsUseCase()(
      recipeTitle: widget.recipeTitle,
      ingredients: widget.ingredients,
    );
    _rows = drafts.map(_DraftRow.new).toList();
    final name = 'Nấu ${widget.recipeTitle.trim()}';
    _newListName = TextEditingController(
      text: name.length > 100 ? name.substring(0, 100) : name,
    );
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.quantity.dispose();
    }
    _newListName.dispose();
    super.dispose();
  }

  int get _selectedCount => _rows.where((row) => row.selected).length;

  Future<void> _save() async {
    final drafts = <ShoppingItemDraft>[];
    for (final row in _rows.where((row) => row.selected)) {
      final quantity = double.tryParse(
        row.quantity.text.trim().replaceAll(',', '.'),
      );
      if (quantity == null || quantity <= 0) {
        ToastHelper.show(
          context,
          'Vui lòng kiểm tra số lượng của "${row.draft.name}"',
          isError: true,
        );
        return;
      }
      drafts.add(row.draft.copyWith(quantity: quantity, unit: row.unit));
    }
    final isNewList = (_listId ?? _newListValue) == _newListValue;
    final listName = _newListName.text.trim();
    if (isNewList && listName.isEmpty) {
      ToastHelper.show(context, 'Vui lòng nhập tên danh sách.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final controller = ref.read(shoppingControllerProvider);
    try {
      final listId = isNewList
          ? await controller.saveList(name: listName)
          : _listId!;
      final result = await controller.addItems(listId, drafts);
      if (mounted) {
        Navigator.of(context).pop((listId: listId, result: result));
      }
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
    final listsAsync = ref.watch(shoppingListsStreamProvider);
    final lists = listsAsync.valueOrNull;
    // Default to the most recently updated list once the lists arrive.
    if (_listId == null && lists != null) {
      _listId = lists.isEmpty ? _newListValue : lists.first.id;
    }
    final listId = _listId;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lists == null || listId == null)
            const Center(child: CircularProgressIndicator())
          else
            AppDropdown<String>(
              label: 'Danh sách',
              isRequired: true,
              value: listId,
              items: [
                for (final list in lists)
                  DropdownMenuItem(
                    value: list.id,
                    child: Text(list.name, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                  value: _newListValue,
                  child: Text('+ Tạo danh sách mới'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _listId = value ?? _newListValue),
            ),
          if (listId == _newListValue) ...[
            SizedBox(height: 12.h),
            AppTextField(
              label: 'Tên danh sách mới',
              isRequired: true,
              controller: _newListName,
            ),
          ],
          SizedBox(height: 16.h),
          Text(
            'Nguyên liệu cần mua cho ${widget.recipeTitle}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
          ),
          SizedBox(height: 8.h),
          for (final row in _rows) _buildRow(row),
          SizedBox(height: 16.h),
          PrimaryButton(
            text: 'Thêm ($_selectedCount) món',
            isLoading: _isSaving,
            onPressed: _selectedCount == 0 || listId == null ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_DraftRow row) {
    final units = {...shoppingUnits, row.unit}.toList();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: const BorderSide(color: AppColors.slate200),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => row.selected = !row.selected),
                borderRadius: BorderRadius.circular(8.r),
                child: Row(
                  children: [
                    ShoppingCheckbox(checked: row.selected),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        row.draft.name,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: row.selected
                              ? AppColors.slate800
                              : AppColors.slate400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (row.selected) ...[
                SizedBox(height: 10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Số lượng',
                        isRequired: true,
                        controller: row.quantity,
                        fillColor: AppColors.surfaceContainerLowest,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: UnitPickerField(
                        unit: row.unit,
                        units: units,
                        onChanged: (unit) => setState(() => row.unit = unit),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
