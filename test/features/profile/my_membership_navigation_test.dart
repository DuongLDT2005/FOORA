import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/routes/route_names.dart';
import 'package:foora/features/profile/domain/entities/profile.dart';
import 'package:foora/features/profile/presentation/pages/my_membership_page.dart';
import 'package:foora/features/profile/presentation/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('back falls back to profile when membership is the root route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRouteNames.myMembership,
      routes: [
        GoRoute(
          path: AppRouteNames.myMembership,
          builder: (_, _) => const MyMembershipPage(),
        ),
        GoRoute(
          path: AppRouteNames.profile,
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('profile-fallback'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileStreamProvider.overrideWith(
            (ref) => Stream<Profile?>.empty(),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();

    expect(find.text('profile-fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
