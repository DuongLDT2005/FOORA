import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/statistics/domain/entities/status_change_record.dart';
import 'package:foora/features/statistics/domain/usecases/compute_waste_statistics.dart';

void main() {
  const useCase = ComputeWasteStatistics();
  final nowUtc = DateTime.utc(2026, 10, 19, 14, 0); // Oct 2026

  group('ComputeWasteStatistics', () {
    test(
      'returns exact number of monthly buckets with 0 counts when records is empty',
      () {
        final stats6 = useCase(records: [], nowUtc: nowUtc, months: 6);
        expect(stats6.monthly.length, 6);
        expect(stats6.totalConsumed, 0);
        expect(stats6.totalDiscarded, 0);
        expect(stats6.wasteRatePercent, isNull);
        expect(stats6.hasData, isFalse);
        expect(stats6.topWasted, isEmpty);

        // Verify months order: May 2026 to Oct 2026
        expect(stats6.monthly.first.month, 5);
        expect(stats6.monthly.first.year, 2026);
        expect(stats6.monthly.last.month, 10);
        expect(stats6.monthly.last.year, 2026);
      },
    );

    test(
      'correctly counts consumed and discarded items and calculates waste rate',
      () {
        final records = [
          StatusChangeRecord(
            id: '1',
            name: 'Sữa tươi',
            normalizedName: 'sua tuoi',
            categoryId: 'dairy',
            status: InventoryItemStatus.consumed,
            statusChangedAt: DateTime.utc(2026, 10, 10, 8, 0),
            expirationDate: DateTime.utc(2026, 10, 15),
          ),
          StatusChangeRecord(
            id: '2',
            name: 'Sữa tươi',
            normalizedName: 'sua tuoi',
            categoryId: 'dairy',
            status: InventoryItemStatus.consumed,
            statusChangedAt: DateTime.utc(2026, 10, 12, 8, 0),
            expirationDate: DateTime.utc(2026, 10, 15),
          ),
          StatusChangeRecord(
            id: '3',
            name: 'Rau cải',
            normalizedName: 'rau cai',
            categoryId: 'vegetables',
            status: InventoryItemStatus.discarded,
            statusChangedAt: DateTime.utc(2026, 10, 14, 8, 0),
            expirationDate: DateTime.utc(2026, 10, 11), // expired!
          ),
        ];

        final stats = useCase(records: records, nowUtc: nowUtc, months: 6);

        expect(stats.totalConsumed, 2);
        expect(stats.totalDiscarded, 1);
        expect(stats.discardedAfterExpiry, 1);
        // 1 / 3 = 33.333% -> 33.3%
        expect(stats.wasteRatePercent, 33.3);
        expect(stats.hasData, isTrue);

        final currentMonthBucket = stats.monthly.last;
        expect(currentMonthBucket.month, 10);
        expect(currentMonthBucket.consumed, 2);
        expect(currentMonthBucket.discarded, 1);
      },
    );

    test('converts UTC to Vietnam time (UTC+7) for bucket placement', () {
      // 2026-09-30 20:00 UTC is 2026-10-01 03:00 VN time -> October
      final record = StatusChangeRecord(
        id: '1',
        name: 'Thịt bò',
        normalizedName: 'thit bo',
        categoryId: 'meat',
        status: InventoryItemStatus.consumed,
        statusChangedAt: DateTime.utc(2026, 9, 30, 20, 0),
        expirationDate: DateTime.utc(2026, 10, 5),
      );

      final stats = useCase(records: [record], nowUtc: nowUtc, months: 6);

      final sepBucket = stats.monthly.firstWhere((m) => m.month == 9);
      final octBucket = stats.monthly.firstWhere((m) => m.month == 10);

      expect(sepBucket.consumed, 0);
      expect(octBucket.consumed, 1);
    });

    test(
      'groups top wasted foods and limits to 5, sorted by count desc and name asc',
      () {
        final records = [
          for (int i = 0; i < 4; i++)
            StatusChangeRecord(
              id: 'c$i',
              foodId: 'food_apple',
              name: 'Táo Envy',
              normalizedName: 'tao envy',
              categoryId: 'fruit',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 1),
              expirationDate: DateTime.utc(2026, 10, 2),
            ),
          for (int i = 0; i < 3; i++)
            StatusChangeRecord(
              id: 'b$i',
              foodId: 'food_banana',
              name: 'Chuối già',
              normalizedName: 'chuoi gia',
              categoryId: 'fruit',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 2),
              expirationDate: DateTime.utc(2026, 10, 3),
            ),
          for (int i = 0; i < 3; i++)
            StatusChangeRecord(
              id: 'd$i',
              foodId: 'food_durian',
              name: 'Sầu riêng',
              normalizedName: 'sau rieng',
              categoryId: 'fruit',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 2),
              expirationDate: DateTime.utc(2026, 10, 3),
            ),
          for (int i = 0; i < 2; i++)
            StatusChangeRecord(
              id: 'e$i',
              foodId: 'food_egg',
              name: 'Trứng gà',
              normalizedName: 'trung ga',
              categoryId: 'dairy',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 2),
              expirationDate: DateTime.utc(2026, 10, 3),
            ),
          for (int i = 0; i < 1; i++)
            StatusChangeRecord(
              id: 'f$i',
              foodId: 'food_fish',
              name: 'Cá hồi',
              normalizedName: 'ca hoi',
              categoryId: 'seafood',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 2),
              expirationDate: DateTime.utc(2026, 10, 3),
            ),
          for (int i = 0; i < 1; i++)
            StatusChangeRecord(
              id: 'g$i',
              foodId: 'food_ginger',
              name: 'Gừng sẻ',
              normalizedName: 'gung se',
              categoryId: 'spice',
              status: InventoryItemStatus.discarded,
              statusChangedAt: DateTime.utc(2026, 10, 2),
              expirationDate: DateTime.utc(2026, 10, 3),
            ),
        ];

        final stats = useCase(records: records, nowUtc: nowUtc, months: 6);

        // Max 5 items returned
        expect(stats.topWasted.length, 5);
        // Rank 1: Táo Envy (count = 4)
        expect(stats.topWasted[0].name, 'Táo Envy');
        expect(stats.topWasted[0].count, 4);

        // Rank 2 & 3 tied with 3: Chuối già vs Sầu riêng -> alphabetical tie break
        expect(stats.topWasted[1].name, 'Chuối già');
        expect(stats.topWasted[2].name, 'Sầu riêng');

        // Rank 4: Trứng gà (count = 2)
        expect(stats.topWasted[3].name, 'Trứng gà');

        // Rank 5: Cá hồi vs Gừng sẻ tied with 1 -> Cá hồi wins alphabetically
        expect(stats.topWasted[4].name, 'Cá hồi');
      },
    );

    test('ignores records outside of the requested period', () {
      final oldRecord = StatusChangeRecord(
        id: 'old',
        name: 'Gạo cũ',
        normalizedName: 'gao cu',
        categoryId: 'grain',
        status: InventoryItemStatus.discarded,
        // Jan 2026 is outside 6-month period for Oct 2026 (May-Oct)
        statusChangedAt: DateTime.utc(2026, 1, 15),
        expirationDate: DateTime.utc(2026, 1, 10),
      );

      final stats = useCase(records: [oldRecord], nowUtc: nowUtc, months: 6);
      expect(stats.totalDiscarded, 0);
      expect(stats.hasData, isFalse);
    });
  });
}
