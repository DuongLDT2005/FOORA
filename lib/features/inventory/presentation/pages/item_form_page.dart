import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../widgets/date_field_picker_tile.dart';
import '../widgets/food_suggestion_dropdown.dart';
import '../widgets/item_category_location_selectors.dart';
import '../widgets/unit_picker_field.dart';
import '../widgets/shelf_life_rule_alert_banner.dart';
import '../widgets/smart_inventory_alert_banner.dart';

/// Add / edit food item form.
/// Pass [itemToEdit] to edit an existing item (or a receipt draft item);
/// otherwise a new item is created. State lives in [InventoryFormNotifier].
class ItemFormPage extends ConsumerStatefulWidget {
  final InventoryItem? itemToEdit;

  const ItemFormPage({super.key, this.itemToEdit});

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  late final TextEditingController _nameController;

  /// Anchors the suggestion dropdown to the name field, wherever the field
  /// ends up (error banner shown above it, form scrolled).
  final _nameFieldLink = LayerLink();
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
        // Delay dismissing suggestions slightly so tap events on the dropdown can fire
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_nameFocusNode.hasFocus) {
            ref
                .read(inventoryFormNotifierProvider(widget.itemToEdit).notifier)
                .dismissSuggestions();
          }
        });
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

  /// Opens a date picker constrained to the allowed range.
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
              surface: Colors.white,
              onSurface: AppColors.slate800,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              todayForegroundColor: const WidgetStatePropertyAll(
                AppColors.primary,
              ),
              todayBorder: const BorderSide(color: AppColors.primary),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.slate600,
              ),
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
        (formState.storageLocationId.toUpperCase() ==
                StorageLocationCode.freezer.value
            ? 'Ngăn đông'
            : 'Ngăn mát');

    final isFromReceiptDraft =
        widget.itemToEdit != null && widget.itemToEdit!.id.isEmpty;

    // Confirm before discarding unsaved changes.
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
          if (isEditing) {
            ToastHelper.show(context, 'Đã cập nhật thực phẩm thành công!');
          } else {
            await DialogHelper.showInfoDialog(
              context,
              title: 'Đã lưu thành công',
              message: 'Thực phẩm đã được lưu thành công vào kho.',
              buttonText: 'OK',
              icon: LucideIcons.circleCheck,
            );
          }
          if (!context.mounted) return;
          final latestState = ref.read(
            inventoryFormNotifierProvider(widget.itemToEdit),
          );
          final updatedItem = widget.itemToEdit?.copyWith(
            name: latestState.name.trim(),
            categoryId: latestState.categoryId,
            storageLocationId: latestState.storageLocationId,
            quantity: latestState.quantity,
            unit: latestState.unit,
            remainingPercentage: latestState.remainingPercentage,
            purchaseDate: latestState.purchaseDate,
            expirationDate: latestState.expirationDate,
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
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Alert Banner (if validation / server error occurs)
                  if (formState.errorMessage != null)
                    AppErrorBanner(message: formState.errorMessage),

                  // 1. Food Name
                  CompositedTransformTarget(
                    link: _nameFieldLink,
                    child: AppTextField(
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                  ),

                  // Smart Inventory Query Alert Banner
                  if (formState.matchedExistingItem != null) ...[
                    SizedBox(height: 12.h),
                    SmartInventoryAlertBanner(
                      item: formState.matchedExistingItem!,
                    ),
                  ],

                  SizedBox(height: 16.h),

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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Unit (Bottom Sheet Picker)
                      Expanded(
                        child: UnitPickerField(
                          unit: formState.unit.isNotEmpty
                              ? formState.unit
                              : _commonUnits.first,
                          units: _commonUnits,
                          onChanged: formNotifier.onUnitChanged,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // 4. Remaining Percentage (Slider)
                  AppPercentageSlider(
                    value: formState.remainingPercentage.toDouble(),
                    onChanged: formNotifier.onRemainingPercentageChanged,
                  ),

                  SizedBox(height: 20.h),

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

                  SizedBox(height: 16.h),

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

                  SizedBox(height: 32.h),
                ],
              ),
            ),

            // Floating Dropdown Overlay (Topmost element in Stack, covers fields below)
            if (formState.showSuggestions && formState.suggestions.isNotEmpty)
              Positioned(
                top: 0,
                left: 20.w,
                right: 20.w,
                child: CompositedTransformFollower(
                  link: _nameFieldLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  offset: Offset(0, 6.h),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: FoodSuggestionDropdown(
                      suggestions: formState.suggestions,
                      onSelected: (suggestion) {
                        // Update the form first so the controller listener
                        // sees the same name and does not search again.
                        formNotifier.onSelectSuggestion(suggestion);
                        _nameController.text = suggestion.name;
                        _nameController.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.name.length),
                        );
                        _nameFocusNode.unfocus();
                      },
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
