import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/debouncer.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../inventory/domain/entities/food_suggestion.dart';
import '../../../inventory/presentation/widgets/food_suggestion_dropdown.dart';
import '../../../inventory/presentation/widgets/unit_picker_field.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/usecases/parse_voice_shopping_text.dart';
import '../providers/shopping_providers.dart';
import 'shopping_item_tile.dart';

/// Adds an item to [listId] (manual entry or a pre-filled suggestion), or
/// edits [itemToEdit].
class AddEditShoppingItemSheet extends ConsumerStatefulWidget {
  final String listId;
  final ShoppingItem? itemToEdit;
  final ShoppingItemDraft? initialDraft;

  const AddEditShoppingItemSheet({
    super.key,
    required this.listId,
    this.itemToEdit,
    this.initialDraft,
  });

  static Future<void> show(
    BuildContext context, {
    required String listId,
    ShoppingItem? itemToEdit,
    ShoppingItemDraft? initialDraft,
  }) {
    return BottomSheetHelper.show<void>(
      context,
      title: itemToEdit == null ? 'Thêm món cần mua' : 'Sửa món cần mua',
      child: AddEditShoppingItemSheet(
        listId: listId,
        itemToEdit: itemToEdit,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  ConsumerState<AddEditShoppingItemSheet> createState() =>
      _AddEditShoppingItemSheetState();
}

class _AddEditShoppingItemSheetState
    extends ConsumerState<AddEditShoppingItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;

  late String _unit;
  String? _foodId;
  String? _categoryId;
  String _searchQuery = '';
  String _lastName = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    final draft = widget.initialDraft;
    _nameController = TextEditingController(text: item?.name ?? draft?.name);
    _quantityController = TextEditingController(
      text: formatShoppingQuantity(item?.quantity ?? draft?.quantity ?? 1),
    );
    _noteController = TextEditingController(text: item?.note ?? draft?.note);
    _unit = item?.unit ?? draft?.unit ?? shoppingUnits.first;
    _foodId = item?.foodId ?? draft?.foodId;
    _categoryId = item?.categoryId ?? draft?.categoryId;
    _lastName = _nameController.text;
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final value = _nameController.text;
    if (value == _lastName) return;
    _lastName = value;
    // Typing a new name drops the master food picked earlier.
    _foodId = null;
    _searchDebouncer.run(() {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  void _onSuggestionSelected(FoodSuggestion suggestion) {
    _searchDebouncer.cancel();
    _lastName = suggestion.name;
    _nameController.text = suggestion.name;
    setState(() {
      _foodId = suggestion.foodId;
      _categoryId = suggestion.categoryId;
      if (suggestion.defaultUnit.isNotEmpty) _unit = suggestion.defaultUnit;
      _searchQuery = '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = ShoppingItemDraft(
      name: _nameController.text,
      quantity: double.parse(_quantityController.text.replaceAll(',', '.')),
      unit: _unit,
      note: _noteController.text,
      foodId: _foodId,
      categoryId: _categoryId,
      source: widget.initialDraft?.source ?? ShoppingItemSource.manual,
    );

    setState(() => _isSaving = true);
    final controller = ref.read(shoppingControllerProvider);
    try {
      final item = widget.itemToEdit;
      if (item != null) {
        await controller.updateItem(item, draft);
        if (mounted) ToastHelper.show(context, 'Đã cập nhật món');
      } else {
        final result = await controller.addItem(widget.listId, draft);
        if (mounted) {
          ToastHelper.show(
            context,
            result.merged
                ? 'Đã cộng thêm vào món có sẵn trong danh sách'
                : 'Đã thêm vào danh sách',
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
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
    final suggestions = _searchQuery.isEmpty
        ? const <FoodSuggestion>[]
        : ref
                  .watch(shoppingFoodSuggestionsProvider(_searchQuery))
                  .valueOrNull ??
              const <FoodSuggestion>[];
    final units = {...shoppingUnits, _unit}.toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Tên món',
                fillColor: AppColors.surfaceContainerLowest,
                placeholder: 'Ví dụ: Sữa tươi, Trứng gà...',
                controller: _nameController,
                isRequired: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Vui lòng nhập tên món.';
                  return name.length > 100 ? 'Tối đa 100 ký tự.' : null;
                },
              ),
              if (suggestions.isNotEmpty) ...[
                SizedBox(height: 6.h),
                FoodSuggestionDropdown(
                  suggestions: suggestions,
                  onSelected: _onSuggestionSelected,
                ),
              ],
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Số lượng',
                      fillColor: AppColors.surfaceContainerLowest,
                      controller: _quantityController,
                      isRequired: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final value = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        if (value == null || value <= 0) {
                          return 'Phải lớn hơn 0.';
                        }
                        return value > 10000 ? 'Tối đa 10000.' : null;
                      },
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: UnitPickerField(
                      unit: _unit,
                      units: units,
                      onChanged: (unit) => setState(() => _unit = unit),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              AppTextField(
                label: 'Ghi chú',
                fillColor: AppColors.surfaceContainerLowest,
                placeholder: 'Không bắt buộc',
                controller: _noteController,
                maxLines: 2,
                validator: (v) =>
                    (v?.trim().length ?? 0) > 200 ? 'Tối đa 200 ký tự.' : null,
              ),
              SizedBox(height: 24.h),
              PrimaryButton(
                text: widget.itemToEdit == null ? 'Thêm vào danh sách' : 'Lưu',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
