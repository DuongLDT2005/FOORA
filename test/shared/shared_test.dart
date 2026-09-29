import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/shared/components/app_dialog.dart';
import 'package:foora/shared/components/app_search_bar.dart';
import 'package:foora/shared/components/app_segmented_control.dart';
import 'package:foora/shared/components/app_shimmer.dart';
import 'package:foora/shared/extensions/context_extensions.dart';
import 'package:foora/shared/extensions/string_extensions.dart';
import 'package:foora/shared/helpers/debouncer.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('StringExtensions Tests', () {
    test('capitalize transforms first letter', () {
      expect('rau củ'.capitalize(), 'Rau củ');
      expect(''.capitalize(), '');
    });

    test('toTitleCase capitalizes each word', () {
      expect('thịt bò tươi'.toTitleCase(), 'Thịt Bò Tươi');
    });

    test('obscureEmail obscures local part', () {
      expect('duongldt2005@gmail.com'.obscureEmail(), 'd***5@gmail.com');
      expect('ab@gmail.com'.obscureEmail(), 'a*@gmail.com');
      expect('invalid-email'.obscureEmail(), 'invalid-email');
    });

    test('isValidEmail checks email validity', () {
      expect('user@foora.vn'.isValidEmail, isTrue);
      expect('not-an-email'.isValidEmail, isFalse);
    });
  });

  group('Debouncer Tests', () {
    test('debounces multiple executions', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      int callCount = 0;

      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);

      expect(callCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(callCount, 1);

      debouncer.dispose();
    });
  });

  group('Shared UI Components Widget Tests', () {
    testWidgets('AppDialog renders correctly', (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        makeTestableWidget(
          AppDialog(
            title: 'Xóa món ăn',
            message: 'Bạn có chắc chắn muốn xóa?',
            isDestructive: true,
            onConfirm: () => confirmed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xóa món ăn'), findsOneWidget);
      expect(find.text('Bạn có chắc chắn muốn xóa?'), findsOneWidget);
      expect(find.text('Xác nhận'), findsOneWidget);

      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('AppSearchBar triggers callback on input', (tester) async {
      String query = '';

      await tester.pumpWidget(
        makeTestableWidget(
          AppSearchBar(
            debounceDuration: const Duration(milliseconds: 10),
            onChanged: (val) => query = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Thịt heo');
      await tester.pump(const Duration(milliseconds: 30));
      expect(query, 'Thịt heo');
    });

    testWidgets('AppSegmentedControl switches selected item', (tester) async {
      String selected = 'fridge';

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: AppSegmentedControl<String>(
                    selectedValue: selected,
                    items: const [
                      SegmentedItem(value: 'fridge', label: 'Ngăn mát'),
                      SegmentedItem(value: 'freezer', label: 'Ngăn đông'),
                    ],
                    onValueChanged: (val) => setState(() => selected = val),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngăn mát'), findsOneWidget);
      expect(find.text('Ngăn đông'), findsOneWidget);

      await tester.tap(find.text('Ngăn đông'));
      await tester.pumpAndSettle();
      expect(selected, 'freezer');
    });

    testWidgets('AppShimmer and ContextExtensions render without error', (
      tester,
    ) async {
      late bool isMobileContext;

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              isMobileContext = context.isMobile;
              return Scaffold(
                body: Center(child: AppShimmer.box(width: 100, height: 20)),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(isMobileContext, isNotNull);
      expect(find.byType(AppShimmer), findsOneWidget);
    });
  });
}
