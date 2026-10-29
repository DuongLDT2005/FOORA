import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';

/// Creates a shopping list, or renames [listToEdit]. Returns the list id.
class CreateEditShoppingListSheet extends ConsumerStatefulWidget {
  final ShoppingList? listToEdit;

  const CreateEditShoppingListSheet({super.key, this.listToEdit});

  static Future<String?> show(
    BuildContext context, {
    ShoppingList? listToEdit,
  }) {
    return BottomSheetHelper.show<String>(
      context,
      title: listToEdit == null ? 'Tạo danh sách mua sắm' : 'Đổi tên danh sách',
      child: CreateEditShoppingListSheet(listToEdit: listToEdit),
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.listToEdit?.name);
    _noteController = TextEditingController(text: widget.listToEdit?.note);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final listId = await ref
          .read(shoppingControllerProvider)
          .saveList(
            listId: widget.listToEdit?.id,
            name: _nameController.text,
            note: _noteController.text,
          );
      if (mounted) Navigator.of(context).pop(listId);
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
                label: 'Tên danh sách',
                placeholder: 'Ví dụ: Đi chợ cuối tuần',
                controller: _nameController,
                isRequired: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Vui lòng nhập tên danh sách.';
                  return name.length > 100 ? 'Tối đa 100 ký tự.' : null;
                },
              ),
              SizedBox(height: 16.h),
              AppTextField(
                label: 'Ghi chú',
                placeholder: 'Không bắt buộc',
                controller: _noteController,
                maxLines: 2,
                validator: (v) =>
                    (v?.trim().length ?? 0) > 200 ? 'Tối đa 200 ký tự' : null,
              ),
              SizedBox(height: 24.h),
              PrimaryButton(
                text: widget.listToEdit == null ? 'Tạo danh sách' : 'Lưu',
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
