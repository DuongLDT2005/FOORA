import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/payment_provider.dart';

class PaymentQrPage extends ConsumerStatefulWidget {
  const PaymentQrPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentQrPage> createState() => _PaymentQrPageState();
}

class _PaymentQrPageState extends ConsumerState<PaymentQrPage> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(paymentControllerProvider.notifier).watch(widget.paymentId),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(paymentControllerProvider, (_, next) {
      if (!_navigated &&
          {
            PaymentFlowPhase.completed,
            PaymentFlowPhase.expired,
            PaymentFlowPhase.cancelled,
            PaymentFlowPhase.requiresReview,
            PaymentFlowPhase.failed,
          }.contains(next.phase)) {
        _navigated = true;
        context.go(AppRouteNames.paymentResultPath(widget.paymentId));
      }
    });

    final state = ref.watch(paymentControllerProvider);
    final payment = state.payment;
    final remaining = payment?.expiresAt?.difference(_now);
    final seconds = (remaining?.inSeconds ?? 0).clamp(0, 86400);
    final countdown =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';

    return SubpageLayout(
      header: AppHeader(title: 'Quét mã thanh toán', onBack: context.pop),
      body: payment == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(20.r),
              children: [
                Text(
                  'Quét mã bằng ứng dụng ngân hàng',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Không đóng ứng dụng trong khi hệ thống đang xác nhận.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate500,
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Container(
                    width: 260.r,
                    height: 260.r,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: payment.qrCode.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _QrCodeView(data: payment.qrCode),
                  ),
                ),
                SizedBox(height: 20.h),
                _PaymentInfo(
                  amount: NumberFormat.currency(
                    locale: 'vi_VN',
                    symbol: payment.currency,
                    decimalDigits: 0,
                  ).format(payment.amount),
                  account: payment.virtualAccountNumber,
                  description: payment.description,
                  reference: payment.referenceNumber,
                ),
                SizedBox(height: 16.h),
                Text(
                  seconds > 0 ? 'Mã hết hạn sau $countdown' : 'Mã đã hết hạn',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: seconds > 0 ? AppColors.amber700 : AppColors.red600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 20.h),
                AppButton.danger(
                  label: 'Hủy giao dịch',
                  onPressed: () =>
                      ref.read(paymentControllerProvider.notifier).cancel(),
                ),
              ],
            ),
    );
  }
}

class _QrCodeView extends StatelessWidget {
  const _QrCodeView({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    if (data.startsWith('data:image/')) {
      final encoded = data.substring(data.indexOf(',') + 1);
      try {
        return Image.memory(base64Decode(encoded), fit: BoxFit.contain);
      } on FormatException {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
    }
    if (data.startsWith('https://') || data.startsWith('http://')) {
      return Image.network(
        data,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      backgroundColor: AppColors.surfaceContainerLowest,
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({
    required this.amount,
    required this.account,
    required this.description,
    required this.reference,
  });

  final String amount;
  final String account;
  final String description;
  final String reference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Số tiền', value: amount),
          if (account.isNotEmpty)
            _InfoRow(label: 'Số tài khoản', value: account),
          _InfoRow(label: 'Nội dung', value: description),
          _InfoRow(label: 'Mã tham chiếu', value: reference),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105.w,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sao chép',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Đã sao chép')));
              }
            },
          ),
        ],
      ),
    );
  }
}
