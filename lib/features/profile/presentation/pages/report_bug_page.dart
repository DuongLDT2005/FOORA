import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/profile_provider.dart';

class ReportBugPage extends ConsumerStatefulWidget {
  const ReportBugPage({super.key});

  @override
  ConsumerState<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends ConsumerState<ReportBugPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'receipt';

  final List<Map<String, String>> _categories = const [
    {'id': 'receipt', 'name': 'Quét hóa đơn AI'},
    {'id': 'inventory', 'name': 'Kho thực phẩm'},
    {'id': 'ui', 'name': 'Giao diện & Hiển thị'},
    {'id': 'other', 'name': 'Lỗi khác'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file != null) {
      ref.read(bugReportNotifierProvider.notifier).setScreenshot(file.path);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(currentProfileStreamProvider).valueOrNull;
    if (profile == null) {
      ToastHelper.show(
        context,
        'Vui lòng đăng nhập trước khi gửi báo cáo.',
        isError: true,
      );
      return;
    }

    final success = await ref
        .read(bugReportNotifierProvider.notifier)
        .submitReport(
          userId: profile.id,
          userEmail: profile.email,
          category: _selectedCategory,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
        );

    if (mounted) {
      if (success) {
        ToastHelper.show(
          context,
          'Cảm ơn bạn! Báo cáo sự cố đã được gửi đến ban kỹ thuật.',
        );
        ref.read(bugReportNotifierProvider.notifier).reset();
        context.pop();
      } else {
        final err = ref.read(bugReportNotifierProvider).errorMessage;
        ToastHelper.show(
          context,
          err ?? 'Gửi báo cáo thất bại.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(bugReportNotifierProvider);

    return SubpageLayout(
      header: AppHeader(title: 'Báo cáo sự cố', onBack: () => context.pop()),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phân loại sự cố',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
              ),
              SizedBox(height: 10.h),

              // Category Selector
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  return ChoiceChip(
                    label: Text(cat['name']!),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.slate700,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.slate200,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat['id']!);
                      }
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20.h),

              // Form fields
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _titleController,
                      label: 'Tiêu đề sự cố',
                      placeholder: 'Tóm tắt ngắn gọn lỗi gặp phải',
                      prefixIcon: const Icon(LucideIcons.circleAlert),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    AppTextField(
                      controller: _descController,
                      label: 'Mô tả chi tiết',
                      placeholder:
                          'Hãy cho chúng tôi biết các bước để tái hiện lỗi...',
                      maxLines: 4,
                      prefixIcon: const Icon(LucideIcons.fileText),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng mô tả chi tiết lỗi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Screenshot upload area
              Text(
                'Ảnh chụp màn hình minh họa (Không bắt buộc)',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              SizedBox(height: 8.h),
              if (reportState.selectedScreenshotPath != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.file(
                        File(reportState.selectedScreenshotPath!),
                        height: 180.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8.r,
                      right: 8.r,
                      child: GestureDetector(
                        onTap: () => ref
                            .read(bugReportNotifierProvider.notifier)
                            .setScreenshot(null),
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                InkWell(
                  onTap: _pickScreenshot,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.slate300,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.imagePlus,
                          size: 32.r,
                          color: AppColors.slate400,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Nhấn để tải lên ảnh chụp màn hình',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.slate600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16.h),

              // System info note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 14.r, color: AppColors.slate400),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Hệ thống sẽ tự động đính kèm thông tin phiên bản FOORA để kỹ sư xử lý nhanh chóng.',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.slate400,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Submit Button
              AppButton.primary(
                label: 'Gửi báo cáo sự cố',
                icon: LucideIcons.send,
                isLoading: reportState.isLoading,
                onPressed: reportState.isLoading ? null : _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
