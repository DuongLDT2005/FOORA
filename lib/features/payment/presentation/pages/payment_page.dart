import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../providers/payment_provider.dart';

class PaymentPage extends ConsumerWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(membershipPlanProvider('premium'));
    final paymentState = ref.watch(paymentControllerProvider);

    return SubpageLayout(
      header: AppHeader(title: 'Xác nhận thanh toán', onBack: context.pop),
      body: plan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Text(
              'Không thể tải gói Premium: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (membership) => ListView(
          padding: EdgeInsets.all(20.r),
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        color: AppColors.amber500,
                        size: 24.r,
                      ),
                      SizedBox(width: 10.w),
                      Text(membership.name, style: AppTextStyles.headlineSmall),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  _SummaryRow(
                    label: 'Chu kỳ',
                    value: '${membership.durationDays ?? 30} ngày',
                  ),
                  SizedBox(height: 12.h),
                  const _SummaryRow(label: 'Phương thức', value: 'payOS'),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Divider(color: AppColors.slate200),
                  ),
                  _SummaryRow(
                    label: 'Tổng cộng',
                    value: NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: membership.currency,
                      decimalDigits: 0,
                    ).format(membership.price),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            if (paymentState.phase == PaymentFlowPhase.failed) ...[
              SizedBox(height: 16.h),
              AppErrorBanner(message: paymentState.message),
            ],
            SizedBox(height: 20.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 18.r,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Quyền Premium chỉ được kích hoạt sau khi hệ thống xác nhận giao dịch.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 28.h),
            AppButton.primary(
              label: 'Tạo mã QR thanh toán',
              icon: LucideIcons.qrCode,
              isLoading: paymentState.phase == PaymentFlowPhase.creatingOrder,
              onPressed: () async {
                final payment = await ref
                    .read(paymentControllerProvider.notifier)
                    .createOrder(membership.id);
                if (payment != null && context.mounted) {
                  context.push(AppRouteNames.paymentQrPath(payment.id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate500),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: emphasized ? AppColors.primary : AppColors.slate800,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
