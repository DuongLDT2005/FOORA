import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/firebase/firebase_initializer.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notification/presentation/widgets/notification_open_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize AppConfig from resolved environment
  AppConfig.initialize(AppConfig.fromEnv());

  // 2. Initialize Firebase (with emulator if configured)
  await FirebaseInitializer.initialize();

  // 3. Register Firebase Messaging Background Handler (mobile platforms only)
  //    and show pushes that arrive while the app is open.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await LocalNotificationPresenter.instance.initialize();
  }

  // 4. Pre-initialize SharedPreferences for synchronous Riverpod access
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return NotificationOpenListener(
      child: ScreenUtilInit(
        // Standard mobile design frame (iPhone 13/14/15 standard size: 390 x 844)
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'FOORA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: router,
            builder: (context, child) => kIsWeb
                ? child ?? const SizedBox.shrink()
                : _AppZoom(child: child ?? const SizedBox.shrink()),
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}

/// Renders the whole mobile app slightly smaller, like a 90% zoom: pages lay
/// out on a larger logical canvas that is then scaled down to the screen.
/// Fixed theme sizes and ScreenUtil sizes shrink together, so proportions
/// stay as designed. Insets are scaled up by the same factor so the status
/// bar, gesture bar and keyboard still line up after the scale-down.
class _AppZoom extends StatelessWidget {
  const _AppZoom({required this.child});

  static const double _scale = 0.9;

  final Widget child;

  static EdgeInsets _unscale(EdgeInsets insets) => insets / _scale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size / _scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            devicePixelRatio: media.devicePixelRatio * _scale,
            padding: _unscale(media.padding),
            viewPadding: _unscale(media.viewPadding),
            viewInsets: _unscale(media.viewInsets),
            systemGestureInsets: _unscale(media.systemGestureInsets),
          ),
          child: child,
        ),
      ),
    );
  }
}
