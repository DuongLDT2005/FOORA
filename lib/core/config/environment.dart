enum Environment {
  dev,
  prod;

  static Environment fromString(String value) {
    return value.toLowerCase() == 'prod' ? Environment.prod : Environment.dev;
  }
}

class AppEnv {
  AppEnv._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static Environment get environment => Environment.fromString(_env);

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
