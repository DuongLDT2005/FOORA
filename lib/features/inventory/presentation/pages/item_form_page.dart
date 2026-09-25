import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../widgets/date_field_picker_tile.dart';
import '../widgets/item_category_location_selectors.dart';
import '../widgets/shelf_life_rule_alert_banner.dart';
import '../widgets/smart_inventory_alert_banner.dart';

class ItemFormPage extends ConsumerStatefulWidget {
  final InventoryItem? itemToEdit;

  const ItemFormPage({super.key, this.itemToEdit});

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();

  static const List<String> _commonUnits = [
    'quả',
    'hộp',
    'kg',
    'g',
    'miếng',
    'lon',
    'chai',
    'gói',
    'cây',
    'túi',
  ];

  @override
  void initState() {
    super.initState();
    final initialName = widget.itemToEdit?.name ?? '';
    final initialQty = widget.itemToEdit != null
        ? (widget.itemToEdit!.quantity % 1 == 0
              ? widget.itemToEdit!.quantity.toInt().toString()
              : widget.itemToEdit!.quantity.toString())
        : '1';

    _nameController = TextEditingController(text: initialName);
    _quantityController = TextEditingController(text: initialQty);

    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        ref
            .read(inventoryFormNotifierProvider(widget.itemToEdit).notifier)
            .dismissSuggestions();
      }
    });

    _nameController.addListener(() {
      final notifier = ref.read(
        inventoryFormNotifierProvider(widget.itemToEdit).notifier,
      );
      final currentName = ref
          .read(inventoryFormNotifierProvider(widget.itemToEdit))
          .name;
      if (_nameController.text != currentName) {
        notifier.onNameChanged(_nameController.text);
      }
    });

    _quantityController.addListener(() {
      final notifier = ref.read(
        inventoryFormNotifierProvider(widget.itemToEdit).notifier,
      );
      final parsed = double.tryParse(
        _quantityController.text.replaceAll(',', '.'),
      );
      if (parsed != null && parsed > 0) {
        notifier.onQuantityChanged(parsed);
      }
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final effectiveFirstDate = firstDate ?? DateTime(2020);
    final effectiveLastDate = lastDate ?? DateTime(2035);

    // Ensure initialDate stays within [effectiveFirstDate, effectiveLastDate]
    DateTime safeInitialDate = initialDate;
    if (safeInitialDate.isBefore(effectiveFirstDate)) {
      safeInitialDate = effectiveFirstDate;
    } else if (safeInitialDate.isAfter(effectiveLastDate)) {
      safeInitialDate = effectiveLastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.slate800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(
      inventoryFormNotifierProvider(widget.itemToEdit),
    );
    final formNotifier = ref.read(
      inventoryFormNotifierProvider(widget.itemToEdit).notifier,
    );
    final isEditing = widget.itemToEdit != null;
    final selectedLoc = formState.storageLocations
        .where((loc) => loc.id == formState.storageLocationId)
        .firstOrNull;
    final selectedLocName =
        selectedLoc?.name ??
        (formState.storageLocationId == 'freezer' ? 'Ngăn đông' : 'Ngăn mát');

    final isFromReceiptDraft =
        widget.itemToEdit != null && widget.itemToEdit!.id.isEmpty;

    Future<void> handleCancel() async {
      final isDirty =
          _nameController.text.trim().isNotEmpty ||
          (widget.itemToEdit == null && _quantityController.text != '1');
      if (!isDirty) {
        context.pop<InventoryItem?>(null);
        return;
      }
      final shouldLeave = await DialogHelper.showConfirmDialog(
        context,
        title: 'Hủy thay đổi?',
        message: 'Các thông tin bạn vừa nhập sẽ không được lưu lại.',
        confirmText: 'Đồng ý',
        cancelText: 'Tiếp tục sửa',
      );
      if (shouldLeave == true && context.mounted) {
        context.pop<InventoryItem?>(null);
      }
    }

    return SubpageLayout.itemForm(
      isEditing: isEditing,
      isSubmitting: formState.isSubmitting,
      onCancel: handleCancel,
      onSubmit: () async {
        // Update latest text controller values before submission
        formNotifier.onNameChanged(_nameController.text);
        final qty =
            double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
        formNotifier.onQuantityChanged(qty);

        // If this item is being reviewed/edited from a receipt draft (not yet saved to DB)
        if (isFromReceiptDraft) {
          if (formState.name.trim().isEmpty) {
            ToastHelper.show(
              context,
              'Vui lòng nhập tên thực phẩm.',
              isError: true,
            );
            return;
          }
          final updatedDraft = widget.itemToEdit!.copyWith(
            name: formState.name.trim(),
            categoryId: formState.categoryId,
            storageLocationId: formState.storageLocationId,
            quantity: formState.quantity,
            unit: formState.unit,
            remainingPercentage: formState.remainingPercentage,
            purchaseDate: formState.purchaseDate,
            expirationDate: formState.expirationDate,
          );
          context.pop<InventoryItem?>(updatedDraft);
          return;
        }

        final success = await formNotifier.submit();
        if (success && context.mounted) {
          ToastHelper.show(
            context,
            isEditing
                ? 'Đã cập nhật thực phẩm thành công!'
                : 'Đã thêm thực phẩm vào tủ lạnh!',
          );
          final updatedItem = widget.itemToEdit?.copyWith(
            name: formState.name.trim(),
            categoryId: formState.categoryId,
            storageLocationId: formState.storageLocationId,
            quantity: formState.quantity,
            unit: formState.unit,
            remainingPercentage: formState.remainingPercentage,
            purchaseDate: formState.purchaseDate,
            expirationDate: formState.expirationDate,
          );
          context.pop<InventoryItem?>(updatedItem);
        }
      },
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          formNotifier.dismissSuggestions();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Alert Banner (if validation / server error occurs)
                  if (formState.errorMessage != null)
                    AppErrorBanner(message: formState.errorMessage),

                  // 1. Food Name
                  AppTextField(
                    label: 'TÊN THỰC PHẨM',
                    placeholder: 'Ví dụ: Cà chua, Sữa tươi, Táo...',
                    isRequired: true,
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    onSubmitted: formNotifier.onNameChanged,
                    fillColor: Colors.white,
                    borderColor: AppColors.slate100,
                    labelStyle: AppTextStyles.inputLabel.copyWith(
                      color: AppColors.slate600,
                    ),
                    textStyle: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate800,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),

                  // Smart Inventory Query Alert Banner
                  if (formState.matchedExistingItem != null) ...[
                    const SizedBox(height: 12),
                    SmartInventoryAlertBanner(
                      item: formState.matchedExistingItem!,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 2. Category & Storage Location (Isolated component with retry/loading support)
                  ItemCategoryLocationSelectors(
                    isLoading: formState.isLoadingMetadata,
                    categories: formState.categories,
                    storageLocations: formState.storageLocations,
                    selectedCategoryId: formState.categoryId,
                    selectedStorageLocationId: formState.storageLocationId,
                    onCategoryChanged: formNotifier.onCategoryChanged,
                    onLocationChanged: formNotifier.onLocationChanged,
                    onRetry: formNotifier.retryLoadMetadata,
                  ),

                  // 3. Quantity & Unit (2-column grid)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      Expanded(
                        flex: 1,
                        child: AppTextField(
                          label: 'SỐ LƯỢNG',
                          isRequired: true,
                          controller: _quantityController,
                          focusNode: _quantityFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onSubmitted: (val) {
                            final parsed =
                                double.tryParse(val.replaceAll(',', '.')) ?? 1;
                            formNotifier.onQuantityChanged(parsed);
                          },
                          fillColor: Colors.white,
                          borderColor: AppColors.slate100,
                          labelStyle: AppTextStyles.inputLabel.copyWith(
                            color: AppColors.slate600,
                          ),
                          textStyle: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate800,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Unit (Bottom Sheet Picker)
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'ĐƠN VỊ',
                                style: AppTextStyles.inputLabel.copyWith(
                                  color: AppColors.slate600,
                                ),
                                children: const [
                                  TextSpan(
                                    text: ' *',
                                    style: TextStyle(color: AppColors.red500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                BottomSheetHelper.showSelect<String>(
                                  context,
                                  title: 'Đơn vị tính',
                                  isGrid: true,
                                  selectedValue: formState.unit.isNotEmpty
                                      ? formState.unit
                                      : _commonUnits.first,
                                  options: _commonUnits
                                      .map(
                                        (u) => SelectOption(value: u, label: u),
                                      )
                                      .toList(),
                                  onSelected: formNotifier.onUnitChanged,
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate100),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formState.unit.isNotEmpty
                                          ? formState.unit
                                          : _commonUnits.first,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.slate400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Remaining Percentage (Slider)
                  AppPercentageSlider(
                    value: formState.remainingPercentage.toDouble(),
                    onChanged: formNotifier.onRemainingPercentageChanged,
                  ),

                  const SizedBox(height: 20),

                  // 5. Purchase Date (cannot be after expiration date)
                  DateFieldPickerTile(
                    label: 'NGÀY MUA',
                    date: formState.purchaseDate,
                    onTap: () {
                      _pickDate(
                        context: context,
                        initialDate: formState.purchaseDate,
                        lastDate: DateTime(
                          formState.expirationDate.year,
                          formState.expirationDate.month,
                          formState.expirationDate.day,
                        ),
                        onPicked: formNotifier.onPurchaseDateChanged,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 6. Expiration Date (must be equal to or after purchase date)
                  DateFieldPickerTile(
                    label: 'HẠN SỬ DỤNG',
                    date: formState.expirationDate,
                    onTap: () {
                      _pickDate(
                        context: context,
                        initialDate: formState.expirationDate,
                        firstDate: DateTime(
                          formState.purchaseDate.year,
                          formState.purchaseDate.month,
                          formState.purchaseDate.day,
                        ),
                        onPicked: formNotifier.onExpirationDateChanged,
                      );
                    },
                  ),

                  // Shelf Life Rule Alert Banner (Only display when required fields are filled)
                  if (formState.name.trim().isNotEmpty &&
                      formState.categoryId.isNotEmpty &&
                      formState.storageLocationId.isNotEmpty &&
                      formState.unit.isNotEmpty &&
                      formState.quantity > 0)
                    ShelfLifeRuleAlertBanner(
                      maxValue: formState.maxStorageTime,
                      unit: formState.storageTimeUnit,
                      storageLocationName: selectedLocName,
                      hasRule: formState.hasShelfLifeRule,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Floating Dropdown Overlay (Topmost element in Stack, covers fields below)
            if (formState.showSuggestions && formState.suggestions.isNotEmpty)
              Positioned(
                top: 98, // padding top 20 + label + input
                left: 20,
                right: 20,
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: formState.suggestions.take(5).map((suggestion) {
                        final isLast =
                            suggestion == formState.suggestions.take(5).last;

                        return InkWell(
                          onTap: () {
                            _nameController.text = suggestion.name;
                            _nameController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: suggestion.name.length),
                                );
                            formNotifier.onSelectSuggestion(suggestion);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(
                                      bottom: BorderSide(
                                        color: AppColors.slate100,
                                      ),
                                    ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  suggestion.isFromMaster
                                      ? LucideIcons.sparkles
                                      : LucideIcons.history,
                                  size: 16,
                                  color: suggestion.isFromMaster
                                      ? AppColors.primary
                                      : AppColors.slate400,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.name,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.slate800,
                                            ),
                                      ),
                                      if (suggestion.matchedAlias != null &&
                                          suggestion.matchedAlias!.isNotEmpty)
                                        Text(
                                          'Tên khác: ${suggestion.matchedAlias}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (suggestion.defaultUnit.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.slate100,
                                      ),
                                    ),
                                    child: Text(
                                      suggestion.defaultUnit,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.slate500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
