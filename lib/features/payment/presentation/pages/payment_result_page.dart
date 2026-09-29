import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/payment_provider.dart';

class PaymentResultPage extends ConsumerStatefulWidget {
  const PaymentResultPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends ConsumerState<PaymentResultPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(paymentControllerProvider.notifier).watch(widget.paymentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentControllerProvider);
    final presentation = _presentationFor(state.phase);

    return SubpageLayout(
      header: AppHeader(
        title: 'Kết quả thanh toán',
        onBack: () => context.go(AppRouteNames.myMembership),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(presentation.icon, size: 72.r, color: presentation.color),
              SizedBox(height: 20.h),
              Text(
                presentation.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall,
              ),
              SizedBox(height: 10.h),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.slate600,
                ),
              ),
              SizedBox(height: 28.h),
              AppButton.primary(
                label: state.phase == PaymentFlowPhase.completed
                    ? 'Xem gói thành viên'
                    : 'Về gói thành viên',
                onPressed: () => context.go(AppRouteNames.myMembership),
              ),
              SizedBox(height: 12.h),
              AppButton.secondary(
                label: 'Xem lịch sử thanh toán',
                onPressed: () => context.push(AppRouteNames.paymentHistory),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ResultPresentation _presentationFor(PaymentFlowPhase phase) {
    return switch (phase) {
      PaymentFlowPhase.completed => const _ResultPresentation(
        icon: LucideIcons.circleCheck,
        color: AppColors.primary,
        title: 'Thanh toán thành công',
        message: 'Gói Premium đã được kích hoạt.',
      ),
      PaymentFlowPhase.requiresReview => const _ResultPresentation(
        icon: LucideIcons.clockAlert,
        color: AppColors.amber600,
        title: 'Giao dịch đang được đối soát',
        message:
            'Hệ thống đã nhận giao dịch nhưng cần kiểm tra thêm trước khi kích hoạt Premium.',
      ),
      PaymentFlowPhase.expired => const _ResultPresentation(
        icon: LucideIcons.clock,
        color: AppColors.red600,
        title: 'Mã thanh toán đã hết hạn',
        message: 'Hãy tạo một mã QR mới để tiếp tục.',
      ),
      PaymentFlowPhase.cancelled => const _ResultPresentation(
        icon: LucideIcons.circleX,
        color: AppColors.slate500,
        title: 'Giao dịch đã hủy',
        message: 'Premium chưa được kích hoạt.',
      ),
      PaymentFlowPhase.failed => const _ResultPresentation(
        icon: LucideIcons.triangleAlert,
        color: AppColors.red600,
        title: 'Không thể xử lý giao dịch',
        message: 'Vui lòng thử lại sau.',
      ),
      _ => const _ResultPresentation(
        icon: LucideIcons.loaderCircle,
        color: AppColors.primary,
        title: 'Đang xác nhận giao dịch',
        message: 'Trạng thái sẽ được cập nhật tự động.',
      ),
    };
  }
}

class _ResultPresentation {
  const _ResultPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}
