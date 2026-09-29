import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/payment/domain/entities/payment_transaction.dart';
import 'package:foora/features/payment/presentation/widgets/transaction_tile.dart';

void main() {
  final cases = <PaymentStatus, String>{
    PaymentStatus.pending: 'Đang chờ',
    PaymentStatus.completed: 'Thành công',
    PaymentStatus.failed: 'Thất bại',
    PaymentStatus.cancelled: 'Đã hủy',
    PaymentStatus.expired: 'Hết hạn',
    PaymentStatus.requiresReview: 'Đang đối soát',
  };

  for (final entry in cases.entries) {
    testWidgets('transaction tile renders ${entry.key.value}', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: TransactionTile(
                transaction: PaymentTransaction(
                  id: 'payment-1',
                  membershipId: 'premium',
                  amount: 29000,
                  status: entry.key,
                  createdAt: DateTime.utc(2026),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('FOORA Premium'), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
