import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/shopping_item.dart';
import '../providers/shopping_providers.dart';

class AddEditShoppingItemSheet extends ConsumerStatefulWidget {
  final String listId;
  final ShoppingItem? itemToEdit;

  const AddEditShoppingItemSheet({
    super.key,
    required this.listId,
    this.itemToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required String listId,
    ShoppingItem? itemToEdit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditShoppingItemSheet(
        listId: listId,
        itemToEdit: itemToEdit,
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
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _noteController;

  String? _selectedFoodId;
  bool _isLoading = false;

  final List<String> _commonUnits = [
    'kg',
    'g',
    'quả',
    'trái',
    'bó',
    'hộp',
    'gói',
    'chai',
    'lon',
    'lít',
    'ml',
    'túi',
  ];

  bool get _isEditing => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: item != null
          ? (item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toInt().toString()
              : item.quantity.toString())
          : '1',
    );
    _unitController = TextEditingController(text: item?.unit ?? 'kg');
    _noteController = TextEditingController(text: item?.note ?? '');
    _selectedFoodId = item?.foodId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      ToastHelper.show(context, 'Số lượng phải lớn hơn 0', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final unit = _unitController.text.trim();
      final note = _noteController.text.trim();

      if (_isEditing) {
        await ref.read(shoppingControllerProvider.notifier).updateShoppingItem(
              listId: widget.listId,
              itemId: widget.itemToEdit!.id,
              name: name,
              quantity: quantity,
              unit: unit,
              note: note.isEmpty ? null : note,
              foodId: _selectedFoodId,
            );
        if (mounted) {
          ToastHelper.show(context, 'Đã cập nhật món mua');
          Navigator.of(context).pop();
        }
      } else {
        await ref.read(shoppingControllerProvider.notifier).addShoppingItem(
              listId: widget.listId,
              name: name,
              quantity: quantity,
              unit: unit,
              note: note.isEmpty ? null : note,
              foodId: _selectedFoodId,
            );
        if (mounted) {
          ToastHelper.show(context, 'Đã thêm vào danh sách');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Có lỗi xảy ra: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInventoryPicker() {
    final inventoryItemsAsync = ref.read(activeHouseholdInventoryStreamProvider);
    final items = inventoryItemsAsync.valueOrNull ?? [];

    if (items.isEmpty) {
      ToastHelper.show(context, 'Tủ lạnh chưa có thực phẩm nào');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: 0.6.sh,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chọn thực phẩm từ tủ lạnh',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamilyHeadline,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20.r, color: AppColors.slate500),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.slate100),
                  itemBuilder: (context, index) {
                    final invItem = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          LucideIcons.salad,
                          color: AppColors.primary,
                          size: 20.r,
                        ),
                      ),
                      title: Text(
                        invItem.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                      subtitle: Text(
                        'Đơn vị: ${invItem.unit}',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.slate500),
                      ),
                      trailing: Icon(LucideIcons.plus, size: 18.r, color: AppColors.primary),
                      onTap: () {
                        setState(() {
                          _nameController.text = invItem.name;
                          _unitController.text = invItem.unit;
                          _selectedFoodId = invItem.foodId;
                        });
                        Navigator.of(bottomSheetContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: bottomInset + 20.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Sửa món cần mua' : 'Thêm món cần mua',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamilyHeadline,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 20.r, color: AppColors.slate500),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Quick Pick Button
              if (!_isEditing) ...[
                OutlinedButton.icon(
                  onPressed: _showInventoryPicker,
                  icon: Icon(LucideIcons.refrigerator, size: 16.r, color: AppColors.primary),
                  label: Text(
                    'Chọn nhanh từ tủ lạnh',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Tên thực phẩm
              Text(
                'Tên thực phẩm *',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Thịt bò, Cà chua, Sữa tươi...',
                  hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.slate400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên thực phẩm';
                  }
                  return null;
                },
              ),
              SizedBox(height: 14.h),

              // Row: Số lượng & Đơn vị tính
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Số lượng
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số lượng *',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: '1',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.slate200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.slate200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Cần nhập số lượng';
                            }
                            final d = double.tryParse(val.trim());
                            if (d == null || d <= 0) {
                              return '> 0';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Đơn vị
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn vị tính *',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        TextFormField(
                          controller: _unitController,
                          style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'kg, hộp...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.slate200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.slate200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Cần đơn vị';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // Chip gợi ý đơn vị tính phổ biến
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: _commonUnits.map((u) {
                  final isSelected = _unitController.text == u;
                  return ActionChip(
                    label: Text(
                      u,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppColors.primary : Colors.black,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.primary,
                      width: isSelected ? 2.0 : 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    onPressed: () {
                      setState(() {
                        _unitController.text = u;
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 14.h),

              // Ghi chú
              Text(
                'Ghi chú (tùy chọn)',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _noteController,
                style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Mua loại tươi ngon, không lấy mỡ...',
                  hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.slate400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                ),
              ),
              SizedBox(height: 24.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isEditing ? 'Lưu thay đổi' : 'Thêm vào danh sách',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
