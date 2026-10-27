class AppConstants {
  AppConstants._();

  static const String appName = 'FOORA';
  static const int defaultPageSize = 20;
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Longer than the 90 s `aiAssistant` callable timeout, so the client does
  /// not give up while the server is still trying AI models.
  static const Duration aiAssistantTimeout = Duration(seconds: 70);
  static const String defaultDateFormat = 'dd/MM/yyyy';
  static const String firebaseRegion = 'asia-southeast1';

  /// Suggested shelf life when neither `shelf_life_rules` nor the category's
  /// `defaultShelfLife` has a recommendation. The user can always edit it.
  static const int fallbackFridgeShelfLifeDays = 3;
  static const int fallbackFreezerShelfLifeDays = 30;
}
