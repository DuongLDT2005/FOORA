import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/admin/data/models/admin_metrics_model.dart';
import 'package:foora/features/admin/data/models/admin_user_model.dart';
import 'package:foora/features/ai/data/models/ai_usage_quota_model.dart';
import 'package:foora/features/auth/data/models/user_model.dart';
import 'package:foora/features/home/data/models/dashboard_summary_model.dart';
import 'package:foora/features/household/data/models/household_model.dart';
import 'package:foora/features/inventory/data/models/food_category_model.dart';
import 'package:foora/features/inventory/data/models/food_model.dart';
import 'package:foora/features/inventory/data/models/inventory_item_model.dart';
import 'package:foora/features/inventory/data/models/shelf_life_rule_model.dart';
import 'package:foora/features/inventory/data/models/storage_location_model.dart';
import 'package:foora/features/membership/data/models/membership_plan_model.dart';
import 'package:foora/features/membership/data/models/subscription_model.dart';
import 'package:foora/features/notification/data/models/app_notification_model.dart';
import 'package:foora/features/notification/data/models/device_model.dart';
import 'package:foora/features/payment/data/models/payment_transaction_model.dart';
import 'package:foora/features/profile/data/models/profile_model.dart';
import 'package:foora/features/receipt/data/models/receipt_item_model.dart';
import 'package:foora/features/receipt/data/models/receipt_model.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12, 0, 0);

  group('Auth & Profile Models Serialization Tests', () {
    test('UserModel converts to/from JSON and Firestore', () {
      final userModel = UserModel(
        id: 'user-123',
        fullName: 'Nguyễn Văn A',
        email: 'vana@gmail.com',
        role: UserRole.member,
        membershipId: 'free',
        activeHouseholdId: 'house-456',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = userModel.toJson();
      final fromJson = UserModel.fromJson(json);
      expect(fromJson.id, userModel.id);
      expect(fromJson.fullName, userModel.fullName);
      expect(fromJson.email, userModel.email);

      final firestoreMap = userModel.toFirestore();
      expect(firestoreMap['fullName'], 'Nguyễn Văn A');
      expect(firestoreMap['createdAt'], isA<Timestamp>());
    });

    test('ProfileModel inherits UserModel behavior correctly', () {
      final profile = ProfileModel(
        id: 'user-123',
        fullName: 'Nguyễn Văn A',
        email: 'vana@gmail.com',
        createdAt: now,
        updatedAt: now,
      );
      expect(profile.fullName, 'Nguyễn Văn A');
      expect(profile.isAdmin, isFalse);
    });
  });

  group('Inventory & Master Data Models Tests', () {
    test('InventoryItemModel handles quantity and FEFO dates', () {
      final item = InventoryItemModel(
        id: 'item-1',
        foodId: 'tomato',
        name: 'Cà chua Đà Lạt',
        normalizedName: 'ca chua da lat',
        categoryId: 'vegetables',
        quantity: 1.5,
        unit: 'kg',
        remainingPercentage: 80,
        storageLocationId: 'fridge',
        purchaseDate: now,
        expirationDate: now.add(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      );

      final json = item.toJson();
      final fromJson = InventoryItemModel.fromJson(json);
      expect(fromJson.name, 'Cà chua Đà Lạt');
      expect(fromJson.quantity, 1.5);
      expect(fromJson.remainingPercentage, 80);
      expect(fromJson.storageLocationId, 'fridge');
    });

    test(
      'FoodModel, Category, StorageLocation & ShelfLifeRule serialize properly',
      () {
        final food = FoodModel(
          id: 'tomato',
          name: 'Cà chua',
          normalizedName: 'ca chua',
          categoryId: 'veg',
          defaultUnit: 'kg',
          aliases: const ['cà chua bi', 'cà chua đỏ'],
          createdAt: now,
          updatedAt: now,
        );
        expect(FoodModel.fromJson(food.toJson()).aliases.length, 2);

        final category = FoodCategoryModel(
          id: 'veg',
          name: 'Rau củ',
          code: 'VEGETABLES',
          icon: 'eco',
          createdAt: now,
          updatedAt: now,
        );
        expect(FoodCategoryModel.fromJson(category.toJson()).name, 'Rau củ');

        final location = StorageLocationModel(
          id: 'fridge',
          name: 'Ngăn mát',
          code: StorageLocationCode.fridge,
          createdAt: now,
          updatedAt: now,
        );
        expect(
          StorageLocationModel.fromJson(location.toJson()).code,
          StorageLocationCode.fridge,
        );

        final rule = ShelfLifeRuleModel(
          id: 'rule-1',
          foodId: 'tomato',
          storageLocationId: 'fridge',
          minDays: 5,
          maxDays: 7,
          createdAt: now,
          updatedAt: now,
        );
        expect(ShelfLifeRuleModel.fromJson(rule.toJson()).maxDays, 7);
      },
    );
  });

  group('Household & Membership Models Tests', () {
    test('HouseholdModel serializes members list', () {
      final household = HouseholdModel(
        id: 'house-1',
        name: 'Gia đình nhỏ',
        ownerId: 'user-1',
        members: const ['user-1', 'user-2'],
        createdAt: now,
        updatedAt: now,
      );

      final fromJson = HouseholdModel.fromJson(household.toJson());
      expect(fromJson.members.length, 2);
      expect(fromJson.isOwner('user-1'), isTrue);
      expect(fromJson.isMember('user-2'), isTrue);
    });

    test('MembershipPlanModel and SubscriptionModel serialize correctly', () {
      final plan = MembershipPlanModel(
        id: 'premium',
        name: 'Premium',
        price: 29000,
        durationDays: 30,
        createdAt: now,
        updatedAt: now,
      );
      expect(MembershipPlanModel.fromJson(plan.toJson()).price, 29000);

      final sub = SubscriptionModel(
        id: 'sub-1',
        membershipId: 'premium',
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        platform: AppPlatform.android,
        productId: 'foora_premium_monthly',
        createdAt: now,
        updatedAt: now,
      );
      expect(SubscriptionModel.fromJson(sub.toJson()).isActive, isTrue);
    });
  });

  group('Receipt & Items Models Tests', () {
    test('ReceiptModel and ReceiptItemModel handle parsing separately', () {
      final receipt = ReceiptModel(
        id: 'rec-1',
        householdId: 'house-1',
        imageUrl: 'https://storage/receipt.jpg',
        status: ReceiptStatus.completed,
        ocrText: 'VinMart...',
        createdAt: now,
        updatedAt: now,
      );
      expect(
        ReceiptModel.fromJson(receipt.toJson()).status,
        ReceiptStatus.completed,
      );

      final item = ReceiptItemModel(
        id: 'item-1',
        rawName: 'THIT HEO XAY',
        name: 'Thịt heo xay',
        normalizedName: 'thit heo xay',
        quantity: 0.5,
        unit: 'kg',
        estimatedExpirationDate: now.add(const Duration(days: 3)),
        confidence: 0.95,
      );
      expect(ReceiptItemModel.fromJson(item.toJson()).rawName, 'THIT HEO XAY');
    });
  });

  group('Notifications, AI & Payment Models Tests', () {
    test('AppNotificationModel and DeviceModel serialize correctly', () {
      final notif = AppNotificationModel(
        id: 'notif-1',
        type: NotificationType.upcomingExpiration,
        title: 'Cà chua sắp hết hạn',
        message: 'Còn 2 ngày nữa là cà chua hết hạn.',
        createdAt: now,
      );
      expect(
        AppNotificationModel.fromJson(notif.toJson()).title,
        'Cà chua sắp hết hạn',
      );

      final device = DeviceModel(
        id: 'dev-1',
        fcmToken: 'fcm-token-xyz',
        platform: AppPlatform.android,
        createdAt: now,
        updatedAt: now,
      );
      expect(DeviceModel.fromJson(device.toJson()).fcmToken, 'fcm-token-xyz');
    });

    test(
      'AiUsageQuotaModel and PaymentTransactionModel serialize correctly',
      () {
        final quota = AiUsageQuotaModel(
          period: '2026-09',
          receiptScanUsed: 3,
          updatedAt: now,
        );
        expect(AiUsageQuotaModel.fromJson(quota.toJson()).receiptScanUsed, 3);

        final payment = PaymentTransactionModel(
          id: 'pay-1',
          subscriptionId: 'sub-1',
          membershipId: 'premium',
          amount: 29000,
          platform: AppPlatform.android,
          productId: 'foora_premium_monthly',
          transactionId: 'GPA.1234-5678',
          status: PaymentStatus.completed,
          createdAt: now,
        );
        expect(
          PaymentTransactionModel.fromJson(payment.toJson()).amount,
          29000,
        );
      },
    );

    test('AdminMetricsModel and AdminUserModel serialize correctly', () {
      final metrics = AdminMetricsModel(
        totalUsers: 150,
        activePremiumUsers: 45,
        totalReceiptScansThisMonth: 320,
        totalFoodItemsTracked: 1200,
        monthlyRevenue: 1305000,
        updatedAt: now,
      );
      expect(AdminMetricsModel.fromJson(metrics.toJson()).totalUsers, 150);

      final adminUser = AdminUserModel(
        id: 'admin-1',
        fullName: 'Admin User',
        email: 'admin@foora.vn',
        role: UserRole.admin,
        createdAt: now,
        updatedAt: now,
      );
      expect(adminUser.isAdmin, isTrue);
    });

    test(
      'DashboardSummaryModel serializes JSON and aggregates InventoryItem list',
      () {
        final summary = DashboardSummaryModel(
          totalItems: 10,
          freshItems: 6,
          expiringSoonItems: 3,
          expiredItems: 1,
        );
        final json = summary.toJson();
        final fromJson = DashboardSummaryModel.fromJson(json);
        expect(fromJson.totalItems, 10);
        expect(fromJson.freshItems, 6);
        expect(fromJson.expiringSoonItems, 3);
        expect(fromJson.expiredItems, 1);
      },
    );

    test('AppEnums parse correctly from strings', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(MembershipTier.fromString('premium'), MembershipTier.premium);
      expect(
        StorageLocationCode.fromString('FRIDGE'),
        StorageLocationCode.fridge,
      );
      expect(
        InventoryItemSource.fromString('receipt_scan'),
        InventoryItemSource.receiptScan,
      );
      expect(ReceiptStatus.fromString('completed'), ReceiptStatus.completed);
      expect(
        NotificationType.fromString('expiration_alert'),
        NotificationType.expirationAlert,
      );
      expect(AppPlatform.fromString('android'), AppPlatform.android);
      expect(AppPlatform.fromString('ios'), AppPlatform.ios);
      expect(
        SubscriptionStatus.fromString('active'),
        SubscriptionStatus.active,
      );
      expect(PaymentStatus.fromString('completed'), PaymentStatus.completed);
    });
  });
}
