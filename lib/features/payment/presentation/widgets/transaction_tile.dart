import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/payment_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(transaction.status);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 42.r,
            height: 42.r,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: status.color, size: 21.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOORA Premium',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  status.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            NumberFormat.currency(
              locale: 'vi_VN',
              symbol: transaction.currency,
              decimalDigits: 0,
            ).format(transaction.amount),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.slate800,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  _StatusPresentation _statusPresentation(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.pending => const _StatusPresentation(
        'Đang chờ',
        AppColors.amber600,
        LucideIcons.clock,
      ),
      PaymentStatus.completed => const _StatusPresentation(
        'Thành công',
        AppColors.primary,
        LucideIcons.circleCheck,
      ),
      PaymentStatus.failed => const _StatusPresentation(
        'Thất bại',
        AppColors.red600,
        LucideIcons.triangleAlert,
      ),
      PaymentStatus.cancelled => const _StatusPresentation(
        'Đã hủy',
        AppColors.slate500,
        LucideIcons.circleX,
      ),
      PaymentStatus.expired => const _StatusPresentation(
        'Hết hạn',
        AppColors.red600,
        LucideIcons.clock,
      ),
      PaymentStatus.requiresReview => const _StatusPresentation(
        'Đang đối soát',
        AppColors.amber700,
        LucideIcons.clockAlert,
      ),
    };
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
