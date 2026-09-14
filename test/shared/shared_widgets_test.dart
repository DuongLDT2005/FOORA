import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/shared/widgets/app_button.dart';
import 'package:foora/shared/widgets/app_card.dart';
import 'package:foora/shared/widgets/app_text_field.dart';
import 'package:foora/shared/widgets/empty_state.dart';
import 'package:foora/shared/widgets/error_state.dart';
import 'package:foora/shared/widgets/status_badge.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Shared Core Widgets UI Tests', () {
    testWidgets('PrimaryButton and SecondaryButton trigger onPressed', (
      tester,
    ) async {
      bool primaryClicked = false;
      bool secondaryClicked = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Column(
            children: [
              PrimaryButton(
                text: 'Lưu thay đổi',
                onPressed: () => primaryClicked = true,
              ),
              SecondaryButton(
                text: 'Hủy bỏ',
                onPressed: () => secondaryClicked = true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(find.text('Hủy bỏ'), findsOneWidget);

      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(primaryClicked, isTrue);

      await tester.tap(find.text('Hủy bỏ'));
      await tester.pumpAndSettle();
      expect(secondaryClicked, isTrue);
    });

    testWidgets(
      'PrimaryButton shows CircularProgressIndicator when isLoading is true',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            const PrimaryButton(text: 'Đang lưu', isLoading: true),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Đang lưu'), findsNothing);
      },
    );

    testWidgets('AppTextField displays label, placeholder and captures input', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        makeTestableWidget(
          AppTextField(
            label: 'Tên thực phẩm',
            placeholder: 'Nhập tên món ăn...',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelFinder = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('TÊN THỰC PHẨM'),
      );
      expect(labelFinder, findsOneWidget);
      expect(find.text('Nhập tên món ăn...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sữa chua nha đam');
      await tester.pumpAndSettle();

      expect(controller.text, equals('Sữa chua nha đam'));
    });

    testWidgets('StatusBadge renders custom and factory badges correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Column(
            children: [
              StatusBadge.expired(),
              StatusBadge.warning(),
              StatusBadge.premium(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hết hạn'), findsOneWidget);
      expect(find.text('Sắp hết'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget);
    });

    testWidgets('EmptyStateWidget renders title, subtitle and action', (
      tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          EmptyStateWidget(
            title: 'Chưa có thực phẩm nào',
            subtitle: 'Thêm thực phẩm để quản lý hạn dùng tốt hơn',
            action: ElevatedButton(
              onPressed: () => actionTapped = true,
              child: const Text('Thêm ngay'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có thực phẩm nào'), findsOneWidget);
      expect(
        find.text('Thêm thực phẩm để quản lý hạn dùng tốt hơn'),
        findsOneWidget,
      );
      expect(find.text('Thêm ngay'), findsOneWidget);

      await tester.tap(find.text('Thêm ngay'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });

    testWidgets('AppErrorBanner displays error message', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AppErrorBanner(message: 'Không thể kết nối mạng'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không thể kết nối mạng'), findsOneWidget);
    });

    testWidgets('FeatureCard renders title, subtitle and handles tap', (
      tester,
    ) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          FeatureCard(
            icon: Icons.camera_alt,
            title: 'Quét hóa đơn AI',
            subtitle: 'Tự động nhận diện thực phẩm',
            onTap: () => cardTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quét hóa đơn AI'), findsOneWidget);
      expect(find.text('Tự động nhận diện thực phẩm'), findsOneWidget);

      await tester.tap(find.text('Quét hóa đơn AI'));
      await tester.pumpAndSettle();
      expect(cardTapped, isTrue);
    });
  });
}
