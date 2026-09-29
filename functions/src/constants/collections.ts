/**
 * Centralized Firestore collection names and document IDs.
 * Strictly aligned with docs/DATABASE.md and
 * lib/core/constants/firestore_constants.dart
 */
export const Collections = {
  // Root Collections
  USERS: "users",
  HOUSEHOLDS: "households",
  MEMBERSHIPS: "memberships",
  FOODS: "foods",
  FOOD_CATEGORIES: "food_categories",
  STORAGE_LOCATIONS: "storage_locations",
  SHELF_LIFE_RULES: "shelf_life_rules",
  PAYMENT_REFERENCES: "payment_references",
  PAYMENT_ORDER_LOCKS: "payment_order_locks",
  PAYMENT_PROVIDER_TRANSACTIONS: "payment_provider_transactions",

  // Users Subcollections (users/{userId}/...)
  SUBSCRIPTIONS: "subscriptions",
  RECEIPTS: "receipts",
  RECEIPT_ITEMS: "items",
  NOTIFICATIONS: "notifications",
  DEVICES: "devices",
  AI_USAGE: "ai_usage",
  PAYMENTS: "payments",

  // Households Subcollections (households/{householdId}/...)
  INVENTORY_ITEMS: "inventory_items",

  // Fixed Document IDs
  AI_USAGE_CURRENT_DOC: "current",
} as const;
