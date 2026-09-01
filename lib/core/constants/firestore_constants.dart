class FirestoreConstants {
  FirestoreConstants._();

  // Root Collections
  static const String users = 'users';
  static const String households = 'households';
  static const String memberships = 'memberships';
  static const String foods = 'foods';
  static const String foodCategories = 'food_categories';
  static const String storageLocations = 'storage_locations';
  static const String shelfLifeRules = 'shelf_life_rules';

  // Users Subcollections
  static const String subscriptions = 'subscriptions';
  static const String receipts = 'receipts';
  static const String receiptItems = 'items';
  static const String notifications = 'notifications';
  static const String devices = 'devices';
  static const String aiUsage = 'ai_usage';
  static const String payments = 'payments';

  // Households Subcollections
  static const String inventoryItems = 'inventory_items';

  // Fixed Document IDs
  static const String aiUsageCurrentDoc = 'current';
}
