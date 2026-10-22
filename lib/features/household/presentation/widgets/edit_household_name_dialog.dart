import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/household_provider.dart';

class EditHouseholdNameDialog extends ConsumerStatefulWidget {
  final String householdId;
  final String currentName;

  const EditHouseholdNameDialog({
    super.key,
    required this.householdId,
    required this.currentName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String householdId,
    required String currentName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => EditHouseholdNameDialog(
        householdId: householdId,
        currentName: currentName,
      ),
    );
  }

  @override
  ConsumerState<EditHouseholdNameDialog> createState() =>
      _EditHouseholdNameDialogState();
}

class _EditHouseholdNameDialogState
    extends ConsumerState<EditHouseholdNameDialog> {
  late final TextEditingController _nameController;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Tên gia đình không được để trống.');
      return;
    }
    if (name.length > 100) {
      setState(() => _errorText = 'Tên không được vượt quá 100 ký tự.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref
          .read(householdControllerProvider)
          .updateName(widget.householdId, name);
      if (mounted) {
        ToastHelper.show(context, 'Đã cập nhật tên gia đình thành công!');
        Navigator.of(context).pop(true);
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() => _errorText = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420.w),
        // Scrolls when the keyboard leaves little room on small phones;
        // dragging or tapping outside the field closes the keyboard.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đổi tên gia đình',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilyHeadline,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Nhập tên mới cho không gian tủ lạnh gia đình của bạn.',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 13.sp,
                    color: AppColors.slate500,
                  ),
                ),
                SizedBox(height: 16.h),
                AppTextField(
                  label: 'Tên gia đình',
                  placeholder: 'VD: Gia đình của tôi',
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_isLoading) _save();
                  },
                ),
                if (_errorText != null) ...[
                  SizedBox(height: 6.h),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamilySans,
                      fontSize: 12.sp,
                      color: AppColors.red600,
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Hủy',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: PrimaryButton(
                        text: 'Lưu',
                        isLoading: _isLoading,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
