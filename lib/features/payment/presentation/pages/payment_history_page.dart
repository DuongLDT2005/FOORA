import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/payment_provider.dart';
import '../widgets/transaction_tile.dart';

class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(paymentHistoryProvider);

    return SubpageLayout(
      header: AppHeader.paymentHistory(onBack: context.pop),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Không thể tải lịch sử thanh toán.',
          onRetry: () => ref.invalidate(paymentHistoryProvider),
        ),
        data: (payments) => payments.isEmpty
            ? const EmptyStateWidget(
                title: 'Chưa có giao dịch',
                subtitle: 'Các giao dịch Premium sẽ xuất hiện tại đây.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(paymentHistoryProvider.future),
                child: ListView.separated(
                  padding: EdgeInsets.all(16.r),
                  itemCount: payments.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    return TransactionTile(transaction: payments[index]);
                  },
                ),
              ),
      ),
    );
  }
}
