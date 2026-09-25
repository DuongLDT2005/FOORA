/**
 * Shared TypeScript types & interfaces for FOORA Cloud Functions.
 * Strictly aligned with docs/DATABASE.md schema definitions.
 */

export type UserRole = "member" | "admin";

export type MembershipTier = "free" | "premium";

export type ReceiptStatus = "pending" | "processing" | "completed" | "failed";

export type NotificationType =
  | "expiration_alert"
  | "upcoming_expiration"
  | "priority_food"
  | "system";

export type SubscriptionStatus = "active" | "cancelled" | "expired";

export type PaymentStatus =
  | "pending"
  | "completed"
  | "failed"
  | "cancelled"
  | "expired"
  | "requires_review";

export type PaymentProvider = "cas";

export type StorageLocationCode = "FRIDGE" | "FREEZER";

export type InventoryItemSource = "manual" | "receipt_scan";

export interface AuthenticatedUser {
  uid: string;
  email: string;
  role: UserRole;
  activeHouseholdId?: string;
  membershipId: string;
  isActive: boolean;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}
