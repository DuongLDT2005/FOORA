class AppRouteNames {
  AppRouteNames._();

  // --- Mobile Routes ---
  static const String auth = '/auth';
  static const String forgotPassword = '/forgot-password';

  // Mobile Tabs
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String scan = '/scan';
  static const String profile = '/profile';

  // Mobile Overlays & Details
  static const String itemForm = '/inventory/item-form';
  static const String expirationManagement = '/inventory/expiration-management';
  static const String notifications = '/notifications';
  static const String profileDetail = '/profile/detail';
  static const String notificationSettings = '/profile/notification-settings';
  static const String myMembership = '/profile/my-membership';
  static const String privacySettings = '/profile/privacy-settings';
  static const String helpCenter = '/profile/help-center';
  static const String contactUs = '/profile/contact';
  static const String reportBug = '/profile/report-bug';
  static const String membership = '/membership';
  static const String paymentHistory = '/payment-history';
  static const String paymentQr = '/payment/:paymentId';
  static const String paymentResult = '/payment/:paymentId/result';

  static String paymentQrPath(String paymentId) => '/payment/$paymentId';
  static String paymentResultPath(String paymentId) =>
      '/payment/$paymentId/result';

  // --- Web Admin Routes ---
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminMemberships = '/admin/memberships';
  static const String adminAiUsage = '/admin/ai-usage';
  static const String adminShelfLifeRules = '/admin/shelf-life-rules';
  static const String adminPayments = '/admin/payments';
}
