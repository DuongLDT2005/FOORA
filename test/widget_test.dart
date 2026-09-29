import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/config/app_config.dart';
import 'package:foora/core/config/environment.dart';
import 'package:foora/core/routes/app_router.dart';
import 'package:foora/features/notification/presentation/widgets/notification_open_listener.dart';
import 'package:foora/main.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    AppConfig.initialize(
      const AppConfig(environment: Environment.dev, useFirebaseEmulator: false),
    );
  });

  testWidgets('App smoke test with router override', (
    WidgetTester tester,
  ) async {
    final testRouter = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('FOORA Home'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
          pushOpenSourceProvider.overrideWithValue(
            PushOpenSource(
              getInitialMessage: () async => null,
              onMessageOpenedApp: const Stream.empty(),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.text('FOORA Home'), findsOneWidget);
  });
}
