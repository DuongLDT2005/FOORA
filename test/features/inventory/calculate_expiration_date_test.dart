import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_constants.dart';
import 'package:foora/features/inventory/domain/entities/shelf_life_duration.dart';
import 'package:foora/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:foora/features/inventory/domain/usecases/calculate_expiration_date.dart';

class _FakeShelfLifeRepository implements InventoryRepository {
  ShelfLifeDuration? shelfLife;
  bool shouldThrow = false;

  @override
  Future<ShelfLifeDuration?> findShelfLife({
    String? foodId,
    required String categoryId,
    required String storageLocationId,
  }) async {
    if (shouldThrow) throw Exception('offline');
    return shelfLife;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeShelfLifeRepository repository;
  late CalculateExpirationDateUseCase useCase;
  final purchaseDate = DateTime(2026, 1, 31);

  setUp(() {
    repository = _FakeShelfLifeRepository();
    useCase = CalculateExpirationDateUseCase(repository);
  });

  Future<ExpirationEstimate> run(String location) => useCase(
    foodId: 'tomato',
    categoryId: 'vegetables',
    storageLocationId: location,
    purchaseDate: purchaseDate,
  );

  test('uses maxValue in days', () async {
    repository.shelfLife = const ShelfLifeDuration(
      minValue: 3,
      maxValue: 5,
      unit: 'days',
    );
    final estimate = await run('fridge');
    expect(estimate.expirationDate, DateTime(2026, 2, 5));
    expect(estimate.hasRule, isTrue);
  });

  test('uses calendar months and weeks', () {
    expect(
      CalculateExpirationDateUseCase.addDuration(purchaseDate, 2, 'weeks'),
      DateTime(2026, 2, 14),
    );
    expect(
      CalculateExpirationDateUseCase.addDuration(
        DateTime(2026, 1, 15),
        6,
        'months',
      ),
      DateTime(2026, 7, 15),
    );
    expect(
      CalculateExpirationDateUseCase.addDuration(purchaseDate, 1, 'years'),
      DateTime(2027, 1, 31),
    );
  });

  test('falls back per location when no recommendation exists', () async {
    repository.shelfLife = null;
    final fridge = await run('fridge');
    final freezer = await run('freezer');
    expect(
      fridge.expirationDate,
      purchaseDate.add(
        const Duration(days: AppConstants.fallbackFridgeShelfLifeDays),
      ),
    );
    expect(
      freezer.expirationDate,
      purchaseDate.add(
        const Duration(days: AppConstants.fallbackFreezerShelfLifeDays),
      ),
    );
    expect(fridge.hasRule, isFalse);
  });

  test(
    '"not recommended" rule (null values) keeps the rule but no date math',
    () async {
      repository.shelfLife = const ShelfLifeDuration();
      final estimate = await run('freezer');
      expect(estimate.hasRule, isFalse);
      expect(estimate.shelfLife, isNotNull);
    },
  );

  test('lookup failure falls back instead of throwing', () async {
    repository.shouldThrow = true;
    final estimate = await run('fridge');
    expect(estimate.hasRule, isFalse);
  });
}
