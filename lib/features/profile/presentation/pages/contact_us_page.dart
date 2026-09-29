import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() => _isSending = false);
      _subjectController.clear();
      _messageController.clear();
      ToastHelper.show(
        context,
        'Yêu cầu hỗ trợ đã được gửi. Chúng tôi sẽ phản hồi sớm nhất qua email.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubpageLayout(
      header: AppHeader(title: 'Liên hệ hỗ trợ', onBack: () => context.pop()),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description
            Text(
              'Chúng tôi luôn sẵn sàng lắng nghe bạn',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Nếu bạn có bất kỳ thắc mắc hoặc cần trợ giúp khi sử dụng FOORA, vui lòng liên hệ qua các kênh dưới đây.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.h),

            // Channels List Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.slate100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildChannelTile(
                    icon: LucideIcons.phoneCall,
                    title: 'Tổng đài chăm sóc khách hàng',
                    value: '1900 6868 (Miễn phí)',
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.slate100,
                  ),
                  _buildChannelTile(
                    icon: LucideIcons.mail,
                    title: 'Email hỗ trợ trực tuyến',
                    value: 'support@foora.vn',
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.slate100,
                  ),
                  _buildChannelTile(
                    icon: LucideIcons.clock,
                    title: 'Thời gian làm việc',
                    value: '08:00 - 21:00 (Thứ 2 - Chủ Nhật)',
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Direct Feedback Form
            Text(
              'Gửi tin nhắn trực tiếp',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.slate100),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _subjectController,
                      label: 'Tiêu đề yêu cầu',
                      placeholder: 'Ví dụ: Hướng dẫn quét hóa đơn',
                      prefixIcon: const Icon(LucideIcons.tag),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 14.h),
                    AppTextField(
                      controller: _messageController,
                      label: 'Nội dung chi tiết',
                      placeholder: 'Mô tả vấn đề bạn đang cần trợ giúp...',
                      maxLines: 4,
                      prefixIcon: const Icon(LucideIcons.messageSquare),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập nội dung';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 18.h),
                    AppButton.primary(
                      label: 'Gửi tin nhắn ngay',
                      icon: LucideIcons.send,
                      isLoading: _isSending,
                      onPressed: _isSending ? null : _handleSendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 18.r, color: AppColors.primary),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
