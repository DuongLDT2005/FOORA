import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/inventory/presentation/widgets/shelf_life_rule_alert_banner.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ShelfLifeRuleAlertBanner Widget Tests', () {
    testWidgets('renders recommended storage time when rule exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const ShelfLifeRuleAlertBanner(
            maxValue: 5,
            unit: 'days',
            storageLocationName: 'Ngăn mát',
            hasRule: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Khuyên dùng bảo quản tối đa') &&
            widget.text.toPlainText().contains('5 ngày') &&
            widget.text.toPlainText().contains('trong Ngăn mát'),
      );

      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('renders fallback text when rule does not exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const ShelfLifeRuleAlertBanner(
            maxValue: null,
            unit: null,
            storageLocationName: 'Ngăn đông',
            hasRule: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có thông tin bảo quản cho vị trí này'),
        findsOneWidget,
      );
    });
  });
}
