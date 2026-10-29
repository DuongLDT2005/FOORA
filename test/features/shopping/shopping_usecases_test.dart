import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/shopping/data/models/shopping_item_model.dart';
import 'package:foora/features/shopping/domain/entities/import_shopping_item_request.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item_draft.dart';
import 'package:foora/features/shopping/domain/usecases/add_shopping_item.dart';
import 'package:foora/features/shopping/domain/usecases/import_shopping_items_to_inventory.dart';
import 'package:foora/features/shopping/domain/usecases/set_shopping_item_purchased.dart';

import 'fake_shopping_repository.dart';

void main() {
  late FakeShoppingRepository repository;

  setUp(() => repository = FakeShoppingRepository());

  group('AddShoppingItemUseCase', () {
    test('trims input, normalizes the name and keeps the source', () async {
      await AddShoppingItemUseCase(repository)(
        householdId: 'home-1',
        listId: 'list-1',
        userId: 'user-1',
        draft: const ShoppingItemDraft(
          name: '  Sữa Tươi ',
          quantity: 2,
          unit: ' hộp ',
          note: '  ',
          source: ShoppingItemSource.voice,
        ),
      );

      final call = repository.addedItems.single;
      expect(call.draft.name, 'Sữa Tươi');
      expect(call.draft.unit, 'hộp');
      expect(call.draft.note, isNull);
      expect(call.draft.source, ShoppingItemSource.voice);
      expect(call.normalizedName, 'sua tuoi');
      expect(call.addedBy, 'user-1');
    });

    test('merges same name and unit, keeps a different unit apart', () async {
      final useCase = AddShoppingItemUseCase(repository);
      Future<AddShoppingItemResult> add(String name, String unit) => useCase(
        householdId: 'home-1',
        listId: 'list-1',
        userId: 'user-1',
        draft: ShoppingItemDraft(name: name, quantity: 1, unit: unit),
      );

      final first = await add('Sữa tươi', 'hộp');
      final second = await add('sua tuoi', 'Hộp');
      final third = await add('Sữa tươi', 'lốc');

      expect(first.merged, isFalse);
      expect(second.merged, isTrue);
      expect(second.itemId, first.itemId);
      expect(third.merged, isFalse);
      expect(repository.quantityOf(first.itemId), 2);
    });

    test('rejects invalid drafts before touching the repository', () {
      final useCase = AddShoppingItemUseCase(repository);
      for (final draft in const [
        ShoppingItemDraft(name: ' ', quantity: 1, unit: 'hộp'),
        ShoppingItemDraft(name: 'Sữa', quantity: 0, unit: 'hộp'),
        ShoppingItemDraft(name: 'Sữa', quantity: 10001, unit: 'hộp'),
        ShoppingItemDraft(name: 'Sữa', quantity: 1, unit: ''),
      ]) {
        expect(
          () => useCase(
            householdId: 'home-1',
            listId: 'list-1',
            userId: 'user-1',
            draft: draft,
          ),
          throwsArgumentError,
        );
      }
      expect(repository.addedItems, isEmpty);
    });
  });

  test('items already in the fridge cannot be unticked', () {
    final item = _item(isPurchased: true, isAddedToInventory: true);

    expect(
      () => SetShoppingItemPurchasedUseCase(repository)(
        householdId: 'home-1',
        item: item,
        purchased: false,
        userId: 'user-1',
      ),
      throwsStateError,
    );
  });

  test('import requires a category and at most 50 items', () {
    final useCase = ImportShoppingItemsToInventoryUseCase(repository);
    ImportShoppingItemRequest request(
      String id, {
      String categoryId = 'dairy',
    }) => ImportShoppingItemRequest(
      shoppingItemId: id,
      storageLocation: StorageLocationCode.fridge,
      categoryId: categoryId,
      actualQuantity: 1,
    );

    expect(
      () => useCase(
        householdId: 'home-1',
        listId: 'list-1',
        items: [request('a', categoryId: '')],
      ),
      throwsArgumentError,
    );
    expect(
      () => useCase(
        householdId: 'home-1',
        listId: 'list-1',
        items: List.generate(51, (i) => request('item-$i')),
      ),
      throwsArgumentError,
    );
  });

  test('new item data matches the Firestore create rule', () {
    final data = ShoppingItemModel.newItemData(
      draft: const ShoppingItemDraft(
        name: 'Sữa tươi',
        quantity: 2,
        unit: 'hộp',
        source: ShoppingItemSource.suggestion,
      ),
      normalizedName: 'sua tuoi',
      addedBy: 'user-1',
    );

    expect(data.keys.toSet(), {
      'name',
      'normalizedName',
      'foodId',
      'categoryId',
      'quantity',
      'unit',
      'note',
      'source',
      'isPurchased',
      'purchasedBy',
      'purchasedAt',
      'isAddedToInventory',
      'inventoryItemId',
      'addedToInventoryAt',
      'addedBy',
      'createdAt',
      'updatedAt',
    });
    expect(data['source'], 'suggestion');
    expect(data['isPurchased'], isFalse);
    expect(data['isAddedToInventory'], isFalse);

    final model = ShoppingItemModel.fromJson(
      {...data, 'createdAt': null, 'updatedAt': null},
      id: 'item-1',
      shoppingListId: 'list-1',
    );
    expect(model.name, 'Sữa tươi');
    expect(model.normalizedName, 'sua tuoi');
    expect(model.source, ShoppingItemSource.suggestion);
  });
}

ShoppingItem _item({
  bool isPurchased = false,
  bool isAddedToInventory = false,
}) {
  return ShoppingItem(
    id: 'item-1',
    shoppingListId: 'list-1',
    name: 'Sữa tươi',
    normalizedName: 'sua tuoi',
    quantity: 2,
    unit: 'hộp',
    isPurchased: isPurchased,
    isAddedToInventory: isAddedToInventory,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );
}
