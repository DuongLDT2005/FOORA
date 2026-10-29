import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';

class CreateEditShoppingListSheet extends ConsumerStatefulWidget {
  final ShoppingList? listToEdit;

  const CreateEditShoppingListSheet({
    super.key,
    this.listToEdit,
  });

  static Future<String?> show(
    BuildContext context, {
    ShoppingList? listToEdit,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEditShoppingListSheet(listToEdit: listToEdit),
    );
  }

  @override
  ConsumerState<CreateEditShoppingListSheet> createState() =>
      _CreateEditShoppingListSheetState();
}

class _CreateEditShoppingListSheetState
    extends ConsumerState<CreateEditShoppingListSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  bool _isLoading = false;

  bool get _isEditing => widget.listToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.listToEdit?.name ?? '');
    _noteController = TextEditingController(text: widget.listToEdit?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(currentHouseholdStreamProvider).valueOrNull;
    if (household == null) {
      ToastHelper.show(context, 'Không tìm thấy gia đình hoạt động', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final note = _noteController.text.trim();

      if (_isEditing) {
        await ref.read(shoppingControllerProvider.notifier).updateShoppingList(
              listId: widget.listToEdit!.id,
              name: name,
              note: note.isEmpty ? null : note,
            );
        if (mounted) {
          ToastHelper.show(context, 'Đã cập nhật danh sách mua sắm');
          Navigator.of(context).pop();
        }
      } else {
        final created = await ref.read(shoppingControllerProvider.notifier).createShoppingList(
              householdId: household.id,
              name: name,
              note: note.isEmpty ? null : note,
            );
        if (mounted) {
          ToastHelper.show(context, 'Đã tạo danh sách mua sắm');
          Navigator.of(context).pop(created);
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
                    _isEditing ? 'Đổi tên danh sách' : 'Tạo danh sách mới',
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
              SizedBox(height: 16.h),

              // Tên danh sách
              Text(
                'Tên danh sách *',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 50,
                style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Đi siêu thị cuối tuần, Mua đồ làm tiệc...',
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
                    return 'Vui lòng nhập tên danh sách';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),

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
                maxLines: 2,
                style: TextStyle(fontSize: 14.sp, color: Colors.black, fontWeight: FontWeight.w500),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Ghé siêu thị gần nhà, mua trước 5h chiều...',
                  hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.slate400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.slate300),
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
                          _isEditing ? 'Lưu thay đổi' : 'Tạo danh sách',
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
