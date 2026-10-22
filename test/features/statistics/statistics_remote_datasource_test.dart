import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/statistics/data/datasources/statistics_remote_datasource.dart';

void main() {
  const householdId = 'home-1';
  late FakeFirebaseFirestore firestore;
  late StatisticsRemoteDataSourceImpl dataSource;

  Future<void> addItem(String id, String status, DateTime changedAt) {
    return firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory_items')
        .doc(id)
        .set({
          'name': 'Item $id',
          'normalizedName': 'item $id',
          'categoryId': 'other',
          'status': status,
          'statusChangedAt': Timestamp.fromDate(changedAt),
          'expirationDate': Timestamp.fromDate(changedAt),
        });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    dataSource = StatisticsRemoteDataSourceImpl(firestore: firestore);

    await addItem('oct01', 'consumed', DateTime.utc(2026, 10, 1));
    await addItem('oct05', 'discarded', DateTime.utc(2026, 10, 5));
    await addItem('oct10', 'consumed', DateTime.utc(2026, 10, 10));
    await addItem('oct15', 'discarded', DateTime.utc(2026, 10, 15));
    await addItem('active', 'active', DateTime.utc(2026, 10, 12));
    await addItem('sep', 'consumed', DateTime.utc(2026, 9, 1));
  });

  test('returns consumed/discarded records in range, newest first', () async {
    final records = await dataSource.getStatusChangeRecords(
      householdId: householdId,
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
    );

    expect(records.map((r) => r.id), ['oct15', 'oct10', 'oct05', 'oct01']);
  });

  test('keeps the most recent records when the limit is reached', () async {
    final records = await dataSource.getStatusChangeRecords(
      householdId: householdId,
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
      limit: 2,
    );

    expect(records.map((r) => r.id), ['oct15', 'oct10']);
  });
}
