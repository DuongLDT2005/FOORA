import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/statistics/data/models/status_change_record_model.dart';

void main() {
  group('StatusChangeRecordModel', () {
    test('parses complete json correctly', () {
      final json = {
        'foodId': 'apple_1',
        'name': 'Táo Envy',
        'normalizedName': 'tao envy',
        'categoryId': 'fruit',
        'status': 'discarded',
        'statusChangedAt': Timestamp.fromDate(
          DateTime.utc(2026, 10, 15, 12, 0),
        ),
        'expirationDate': Timestamp.fromDate(DateTime.utc(2026, 10, 10)),
      };

      final model = StatusChangeRecordModel.fromJson(json, id: 'item_123');

      expect(model.id, 'item_123');
      expect(model.foodId, 'apple_1');
      expect(model.name, 'Táo Envy');
      expect(model.normalizedName, 'tao envy');
      expect(model.categoryId, 'fruit');
      expect(model.status, InventoryItemStatus.discarded);
      expect(model.statusChangedAt.toUtc(), DateTime.utc(2026, 10, 15, 12, 0));
      expect(model.expirationDate.toUtc(), DateTime.utc(2026, 10, 10));
      expect(model.isDiscardedAfterExpiry, isTrue);
    });

    test('falls back to updatedAt when statusChangedAt is missing', () {
      final json = {
        'name': 'Bánh mì',
        'status': 'consumed',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 5, 8, 0)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 8, 0)),
      };

      final model = StatusChangeRecordModel.fromJson(json, id: 'item_bm');

      expect(model.status, InventoryItemStatus.consumed);
      expect(model.statusChangedAt.toUtc(), DateTime.utc(2026, 10, 5, 8, 0));
    });

    test(
      'falls back to createdAt when both statusChangedAt and updatedAt are missing',
      () {
        final json = {
          'name': 'Rau thơm',
          'status': 'discarded',
          'createdAt': '2026-10-02T10:00:00Z',
        };

        final model = StatusChangeRecordModel.fromJson(json, id: 'item_rt');

        expect(model.statusChangedAt, DateTime.utc(2026, 10, 2, 10, 0));
      },
    );

    test('groupKey returns foodId when present, otherwise normalizedName', () {
      final withFoodId = StatusChangeRecordModel.fromJson({
        'foodId': 'meat_pork',
        'name': 'Thịt heo',
      }, id: '1');
      expect(withFoodId.groupKey, 'meat_pork');

      final withoutFoodId = StatusChangeRecordModel.fromJson({
        'name': 'Thịt heo tươi',
      }, id: '2');
      expect(withoutFoodId.groupKey, 'thit heo tuoi');
    });
  });
}
