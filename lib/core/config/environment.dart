import 'package:flutter/foundation.dart';

enum Environment {
  dev,
  prod;

  static Environment fromString(String value) {
    return value.toLowerCase() == 'prod' ? Environment.prod : Environment.dev;
  }
}

class AppEnv {
  AppEnv._();

  static Environment get environment {
    if (const bool.hasEnvironment('ENV')) {
      return Environment.fromString(const String.fromEnvironment('ENV'));
    }
    // A release APK is installed on real phones, which cannot reach the
    // local emulators, so it talks to live Firebase unless told otherwise.
    return kReleaseMode ? Environment.prod : Environment.dev;
  }

  static bool get useFirebaseEmulator {
    // If explicitly provided via --dart-define, override the environment default
    if (const bool.hasEnvironment('USE_FIREBASE_EMULATOR')) {
      return const bool.fromEnvironment('USE_FIREBASE_EMULATOR');
    }
    // Environment defaults: dev -> true, prod -> false
    return environment == Environment.dev;
  }

  static String get emulatorHost {
    return const String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
  }

  static String? get apiBaseUrl {
    const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return url.isEmpty ? null : url;
  }
}
