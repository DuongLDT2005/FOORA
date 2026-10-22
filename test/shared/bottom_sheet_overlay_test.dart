import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/shared/helpers/bottom_sheet_helper.dart';

void main() {
  testWidgets(
    'sheet opened from a nested tab navigator covers the whole screen',
    (tester) async {
      // Mirrors the app shell: tab body in a nested navigator, bottom nav bar
      // drawn by the outer Scaffold.
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () => BottomSheetHelper.show<void>(
                        context,
                        title: 'Sheet',
                        child: const Text('content'),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: const SizedBox(
                height: 80,
                child: Text('NAV BAR'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(MaterialApp));
      final barrier = tester.getRect(find.byType(ModalBarrier).last);
      expect(barrier.size, screen, reason: 'scrim must cover the nav bar too');

      // The sheet route belongs to the root navigator, not the tab navigator.
      final sheetContext = tester.element(find.text('content'));
      expect(
        Navigator.of(sheetContext),
        same(Navigator.of(sheetContext, rootNavigator: true)),
      );
    },
  );
}
