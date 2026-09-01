library;

/// User role in the system: 'member' or 'admin'
enum UserRole {
  member('member'),
  admin('admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.member,
    );
  }
}

/// Membership plan tier: 'free' or 'premium'
enum MembershipTier {
  free('free'),
  premium('premium');

  final String value;
  const MembershipTier(this.value);

  static MembershipTier fromString(String? value) {
    return MembershipTier.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MembershipTier.free,
    );
  }
}

/// Storage location code: 'FRIDGE' or 'FREEZER'
enum StorageLocationCode {
  fridge('FRIDGE'),
  freezer('FREEZER');

  final String value;
  const StorageLocationCode(this.value);

  static StorageLocationCode fromString(String? value) {
    final upper = value?.toUpperCase();
    return StorageLocationCode.values.firstWhere(
      (e) => e.value == upper,
      orElse: () => StorageLocationCode.fridge,
    );
  }
}

/// Source of inventory food item: 'manual' or 'receipt_scan'
enum InventoryItemSource {
  manual('manual'),
  receiptScan('receipt_scan');

  final String value;
  const InventoryItemSource(this.value);

  static InventoryItemSource fromString(String? value) {
    return InventoryItemSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InventoryItemSource.manual,
    );
  }
}

/// Receipt scanning processing status: 'pending', 'processing', 'completed', 'failed'
enum ReceiptStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed');

  final String value;
  const ReceiptStatus(this.value);

  static ReceiptStatus fromString(String? value) {
    return ReceiptStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReceiptStatus.pending,
    );
  }
}

/// Notification type: 'expiration_alert', 'upcoming_expiration', 'priority_food', 'system'
enum NotificationType {
  expirationAlert('expiration_alert'),
  upcomingExpiration('upcoming_expiration'),
  priorityFood('priority_food'),
  system('system');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

/// Device and Payment platform: 'android', 'ios', 'web'
enum AppPlatform {
  android('android'),
  ios('ios'),
  web('web');

  final String value;
  const AppPlatform(this.value);

  static AppPlatform fromString(String? value) {
    return AppPlatform.values.firstWhere(
      (e) => e.value == value?.toLowerCase(),
      orElse: () => AppPlatform.android,
    );
  }
}

/// Subscription status: 'active', 'cancelled', 'expired'
enum SubscriptionStatus {
  active('active'),
  cancelled('cancelled'),
  expired('expired');

  final String value;
  const SubscriptionStatus(this.value);

  static SubscriptionStatus fromString(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SubscriptionStatus.active,
    );
  }
}

/// Payment transaction status: 'pending', 'completed', 'failed'
enum PaymentStatus {
  pending('pending'),
  completed('completed'),
  failed('failed');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String? value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.completed,
    );
  }
}
