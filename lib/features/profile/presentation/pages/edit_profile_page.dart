import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../shared/components/app_bottom_bar.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/profile_provider.dart';
import '../widgets/change_email_dialog.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initializeForm(String fullName, String email) {
    if (_isInitialized) return;
    _fullNameController.text = fullName;
    _emailController.text = email;
    _isInitialized = true;
  }

  Future<void> _save(String userId, String? avatarUrl) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(editProfileNotifierProvider.notifier)
        .saveProfile(
          userId: userId,
          fullName: _fullNameController.text.trim(),
          existingAvatarUrl: avatarUrl,
        );

    if (!mounted) return;
    if (success) {
      ToastHelper.show(context, 'Cập nhật hồ sơ thành công!');
      context.pop();
      return;
    }

    final message = ref.read(editProfileNotifierProvider).errorMessage;
    if (message != null) {
      ToastHelper.show(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileStreamProvider);
    final editState = ref.watch(editProfileNotifierProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: LoadingWidget(message: 'Đang tải hồ sơ...')),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppHeader(title: 'Hồ sơ cá nhân', onBack: () => context.pop()),
        body: Center(child: Text('Không thể tải hồ sơ: $error')),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppHeader(
              title: 'Hồ sơ cá nhân',
              onBack: () => context.pop(),
            ),
            body: const Center(child: Text('Không tìm thấy tài khoản.')),
          );
        }

        _initializeForm(profile.fullName, profile.email);

        return SubpageLayout(
          header: AppHeader(
            title: 'Hồ sơ cá nhân',
            onBack: () => context.pop(),
          ),
          bottomBar: AppBottomBar.form(
            submitLabel: 'Lưu thông tin',
            isSubmitting: editState.isLoading,
            onCancel: () => context.pop(),
            onSubmit: () => _save(profile.id, profile.avatarUrl),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _ProfileField(
                    label: 'Họ và tên',
                    controller: _fullNameController,
                    hintText: 'Nhập họ và tên...',
                    icon: LucideIcons.user,
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        InputValidators.validateRequired(value, 'họ và tên'),
                  ),
                  SizedBox(height: 16.h),
                  _ProfileField(
                    label: 'Email',
                    controller: _emailController,
                    hintText: 'example@foora.com',
                    icon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    onTap: () => ChangeEmailDialog.show(context, profile.email),
                  ),
                  SizedBox(height: 16.h),
                  _ProfileField(
                    label: 'Ngày tham gia',
                    controller: TextEditingController(
                      text: DateFormatter.formatDate(profile.createdAt),
                    ),
                    icon: LucideIcons.calendarDays,
                    readOnly: true,
                    muted: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.readOnly = false,
    this.muted = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: muted ? AppColors.slate500 : AppColors.slate700,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: muted ? AppColors.slate50 : Colors.white,
            prefixIcon: Icon(icon, size: 18.r, color: AppColors.slate400),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            border: _border(AppColors.slate100),
            enabledBorder: _border(AppColors.slate100),
            focusedBorder: _border(AppColors.primary, width: 1.5),
            errorBorder: _border(AppColors.red500),
            focusedErrorBorder: _border(AppColors.red500, width: 1.5),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
