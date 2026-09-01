import 'environment.dart';

class AppConfig {
  final Environment environment;
  final String? apiBaseUrl;
  final bool useFirebaseEmulator;
  final String emulatorHost;

  const AppConfig({
    required this.environment,
    this.apiBaseUrl,
    required this.useFirebaseEmulator,
    this.emulatorHost = '10.0.2.2',
  });

  factory AppConfig.fromEnv() {
    return AppConfig(
      environment: AppEnv.environment,
      apiBaseUrl: AppEnv.apiBaseUrl,
      useFirebaseEmulator: AppEnv.useFirebaseEmulator,
      emulatorHost: AppEnv.emulatorHost,
    );
  }

  static AppConfig? _instance;

  static void initialize(AppConfig config) {
    _instance = config;
  }

  static AppConfig get instance {
    if (_instance == null) {
      throw StateError(
        'AppConfig has not been initialized. Call AppConfig.initialize() first.',
      );
    }
    return _instance!;
  }

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;
}
