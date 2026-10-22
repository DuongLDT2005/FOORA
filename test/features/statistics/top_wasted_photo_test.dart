import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/statistics/data/models/status_change_record_model.dart';
import 'package:foora/features/statistics/domain/entities/status_change_record.dart';
import 'package:foora/features/statistics/domain/usecases/compute_waste_statistics.dart';

StatusChangeRecord _discarded(String id, int day, {String? photoUrl}) {
  return StatusChangeRecord(
    id: id,
    foodId: 'milk',
    name: 'Sữa tươi',
    normalizedName: 'sua tuoi',
    categoryId: 'dairy',
    status: InventoryItemStatus.discarded,
    statusChangedAt: DateTime.utc(2026, 10, day, 8),
    expirationDate: DateTime.utc(2026, 10, 1),
    photoUrl: photoUrl,
  );
}

void main() {
  const useCase = ComputeWasteStatistics();
  final nowUtc = DateTime.utc(2026, 10, 20);

  test('model reads photoUrl from the inventory item document', () {
    final model = StatusChangeRecordModel.fromJson({
      'name': 'Sữa tươi',
      'status': 'discarded',
      'photoUrl': 'https://img/milk.webp',
    }, id: 'x');
    expect(model.photoUrl, 'https://img/milk.webp');
  });

  test('top wasted food uses the newest batch that has a photo', () {
    final stats = useCase(
      nowUtc: nowUtc,
      months: 1,
      records: [
        _discarded('old', 3, photoUrl: 'https://img/old.webp'),
        _discarded('mid', 8, photoUrl: 'https://img/new.webp'),
        _discarded('latest-no-photo', 15),
      ],
    );
    expect(stats.topWasted.single.count, 3);
    expect(stats.topWasted.single.photoUrl, 'https://img/new.webp');
  });

  test('no photo on any batch falls back to null (category icon)', () {
    final stats = useCase(
      nowUtc: nowUtc,
      months: 1,
      records: [
        _discarded('a', 5),
        _discarded('b', 9, photoUrl: ''),
      ],
    );
    expect(stats.topWasted.single.photoUrl, isNull);
  });
}
