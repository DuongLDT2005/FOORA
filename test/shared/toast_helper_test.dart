import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/shared/helpers/toast_helper.dart';

void main() {
  testWidgets('toast stays on screen with a bottom bar and survives pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) {
                          return Scaffold(
                            body: Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  ToastHelper.show(
                                    routeContext,
                                    'Đã thêm thực phẩm vào tủ lạnh!',
                                  );
                                  Navigator.of(routeContext).pop();
                                },
                                child: const Text('save'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
              floatingActionButton: FloatingActionButton(onPressed: () {}),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Đã thêm thực phẩm vào tủ lạnh!'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Đã thêm thực phẩm vào tủ lạnh!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
