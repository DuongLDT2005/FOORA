import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/receipt/domain/entities/receipt_item.dart';
import 'package:foora/features/receipt/domain/repositories/receipt_repository.dart';
import 'package:foora/features/receipt/domain/usecases/confirm_receipt_items.dart';
import 'package:foora/features/receipt/domain/usecases/scan_receipt.dart';
import 'package:foora/features/receipt/presentation/providers/receipt_scan_provider.dart';

class MockReceiptRepository implements ReceiptRepository {
  File? lastScannedFile;
  String? lastHouseholdId;
  List<ReceiptItem>? lastBatchItems;
  String? lastBatchReceiptId;

  List<ReceiptItem> mockItemsToReturn = [];
  int mockScansRemaining = 4;
  String? mockReceiptId = 'rec-123';
  int mockSavedCount = 2;

  @override
  Future<({String? receiptId, List<ReceiptItem> items, int? scansRemaining})>
  scanAndParseReceipt({
    required File imageFile,
    required String householdId,
  }) async {
    lastScannedFile = imageFile;
    lastHouseholdId = householdId;
    return (
      receiptId: mockReceiptId,
      items: mockItemsToReturn,
      scansRemaining: mockScansRemaining,
    );
  }

  @override
  Future<int> batchAddReceiptItems({
    required String householdId,
    required List<ReceiptItem> items,
    String? receiptId,
  }) async {
    lastHouseholdId = householdId;
    lastBatchItems = items;
    lastBatchReceiptId = receiptId;
    return mockSavedCount;
  }
}

void main() {
  late MockReceiptRepository mockRepository;
  late ScanReceiptUseCase scanReceiptUseCase;
  late ConfirmReceiptItemsUseCase confirmReceiptItemsUseCase;

  final now = DateTime(2026, 9, 14, 12, 0);
  final sampleItem1 = ReceiptItem(
    id: 'item-1',
    rawName: 'THIT BO UC 500G',
    name: 'Thịt bò Úc',
    normalizedName: 'thit bo uc',
    foodId: 'food-beef-01',
    categoryId: 'meat',
    quantity: 1,
    unit: 'khay',
    storageLocationId: 'freezer',
    estimatedExpirationDate: now.add(const Duration(days: 30)),
    confidence: 0.95,
  );

  final sampleItem2 = ReceiptItem(
    id: 'item-2',
    rawName: 'SUA TUOI TH 1L',
    name: 'Sữa tươi TH True Milk',
    normalizedName: 'sua tuoi th true milk',
    foodId: 'food-milk-01',
    categoryId: 'dairy',
    quantity: 2,
    unit: 'hộp',
    storageLocationId: 'fridge',
    estimatedExpirationDate: now.add(const Duration(days: 7)),
    confidence: 0.98,
    matchedExistingItem: MatchedStockAlert(
      itemId: 'existing-milk',
      name: 'Sữa tươi TH True Milk',
      quantity: 1,
      unit: 'hộp',
      storageLocationName: 'Ngăn mát',
      expirationDate: now.add(const Duration(days: 2)),
      daysRemaining: 2,
    ),
  );

  setUp(() {
    mockRepository = MockReceiptRepository();
    scanReceiptUseCase = ScanReceiptUseCase(mockRepository);
    confirmReceiptItemsUseCase = ConfirmReceiptItemsUseCase(mockRepository);
  });

  group('Receipt Domain UseCases Tests', () {
    test(
      'ScanReceiptUseCase delegates to repository with correct parameters',
      () async {
        mockRepository.mockItemsToReturn = [sampleItem1, sampleItem2];
        final fakeFile = File('dummy_receipt.jpg');

        final result = await scanReceiptUseCase(
          imageFile: fakeFile,
          householdId: 'house-789',
        );

        expect(mockRepository.lastScannedFile?.path, equals(fakeFile.path));
        expect(mockRepository.lastHouseholdId, equals('house-789'));
        expect(result.receiptId, equals('rec-123'));
        expect(result.items.length, equals(2));
        expect(result.scansRemaining, equals(4));
        expect(result.items.first.name, equals('Thịt bò Úc'));
      },
    );

    test(
      'ConfirmReceiptItemsUseCase adds recognized items to household inventory',
      () async {
        mockRepository.mockSavedCount = 2;

        final count = await confirmReceiptItemsUseCase(
          householdId: 'house-789',
          items: [sampleItem1, sampleItem2],
          receiptId: 'rec-123',
        );

        expect(count, equals(2));
        expect(mockRepository.lastHouseholdId, equals('house-789'));
        expect(mockRepository.lastBatchItems?.length, equals(2));
        expect(mockRepository.lastBatchReceiptId, equals('rec-123'));
      },
    );
  });

  group('Receipt Entities & Alert Tests', () {
    test('MatchedStockAlert detects if item is expiring today', () {
      final alertSoon = MatchedStockAlert(
        itemId: 'item-01',
        name: 'Rau cải',
        quantity: 1,
        unit: 'bó',
        storageLocationName: 'Ngăn mát',
        expirationDate: now,
        daysRemaining: 0,
      );

      final alertLater = MatchedStockAlert(
        itemId: 'item-02',
        name: 'Trứng gà',
        quantity: 10,
        unit: 'quả',
        storageLocationName: 'Ngăn mát',
        expirationDate: now.add(const Duration(days: 3)),
        daysRemaining: 3,
      );

      expect(alertSoon.isExpiringToday, isTrue);
      expect(alertLater.isExpiringToday, isFalse);
    });

    test('ReceiptItem copyWith updates selected fields', () {
      final updated = sampleItem1.copyWith(
        quantity: 3,
        storageLocationId: 'fridge',
      );

      expect(updated.quantity, equals(3));
      expect(updated.storageLocationId, equals('fridge'));
      expect(updated.name, equals(sampleItem1.name));
      expect(updated.id, equals(sampleItem1.id));
    });
  });

  group('ReceiptQuotaStatus Tests', () {
    test('standard free quota calculations', () {
      const quota = ReceiptQuotaStatus(scansUsed: 3, scanLimit: 5);
      expect(quota.isQuotaExceeded, isFalse);
      expect(quota.scansRemaining, equals(2));
    });

    test('exceeded free quota', () {
      const quota = ReceiptQuotaStatus(scansUsed: 5, scanLimit: 5);
      expect(quota.isQuotaExceeded, isTrue);
      expect(quota.scansRemaining, equals(0));
    });

    test('unlimited premium quota', () {
      const quota = ReceiptQuotaStatus(
        scansUsed: 20,
        scanLimit: 5,
        isUnlimited: true,
      );
      expect(quota.isQuotaExceeded, isFalse);
      expect(quota.scansRemaining, greaterThan(1000));
    });
  });

  group('ReceiptScanState State Tests', () {
    test('copyWith properly updates status and parsedItems', () {
      const initialState = ReceiptScanState();
      expect(initialState.status, equals(ScanStatus.idle));
      expect(initialState.parsedItems, isEmpty);

      final updatedState = initialState.copyWith(
        status: ScanStatus.reviewing,
        parsedItems: [sampleItem1, sampleItem2],
        receiptId: 'rec-test',
      );

      expect(updatedState.status, equals(ScanStatus.reviewing));
      expect(updatedState.parsedItems.length, equals(2));
      expect(updatedState.receiptId, equals('rec-test'));
    });
  });
}
