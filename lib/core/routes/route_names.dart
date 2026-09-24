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
  static const String membership = '/membership';
  static const String paymentHistory = '/payment-history';

  // --- Web Admin Routes ---
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminMemberships = '/admin/memberships';
  static const String adminAiUsage = '/admin/ai-usage';
  static const String adminShelfLifeRules = '/admin/shelf-life-rules';
  static const String adminPayments = '/admin/payments';
}
