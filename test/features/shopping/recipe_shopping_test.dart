import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item_draft.dart';
import 'package:foora/features/shopping/domain/entities/shopping_list.dart';
import 'package:foora/features/shopping/domain/usecases/build_recipe_shopping_drafts.dart';
import 'package:foora/features/shopping/presentation/providers/shopping_providers.dart';
import 'package:foora/features/shopping/presentation/widgets/add_recipe_to_shopping_sheet.dart';

import 'fake_shopping_repository.dart';

void main() {
  group('BuildRecipeShoppingDraftsUseCase', () {
    const build = BuildRecipeShoppingDraftsUseCase();

    test('fills a missing amount and unit and tags the AI source', () {
      final drafts = build(
        recipeTitle: 'Canh chua',
        ingredients: const [
          RecipeShoppingIngredient(name: ' Me chua ', unit: ' '),
        ],
      );

      final draft = drafts.single;
      expect(draft.name, 'Me chua');
      expect(draft.quantity, 1);
      expect(draft.unit, recipeFallbackUnit);
      expect(draft.note, 'Cho món Canh chua');
      expect(draft.source, ShoppingItemSource.aiRecipe);
    });

    test('merges the same ingredient and unit, keeps other units apart', () {
      final drafts = build(
        recipeTitle: 'Bò xào',
        ingredients: const [
          RecipeShoppingIngredient(name: 'Thịt bò', quantity: 300, unit: 'g'),
          RecipeShoppingIngredient(name: 'thit bo', quantity: 200, unit: 'G'),
          RecipeShoppingIngredient(name: 'Thịt bò', quantity: 1, unit: 'kg'),
        ],
      );

      expect(drafts.map((d) => (d.name, d.quantity, d.unit)), [
        ('Thịt bò', 500, 'g'),
        ('Thịt bò', 1, 'kg'),
      ]);
    });

    test('keeps values inside the shopping limits', () {
      final drafts = build(
        recipeTitle: 'Tiệc',
        ingredients: [
          RecipeShoppingIngredient(
            name: 'Gạo',
            quantity: 20000,
            unit: 'đơn vị rất rất rất dài',
          ),
          const RecipeShoppingIngredient(name: '   '),
        ],
      );

      final draft = drafts.single;
      expect(draft.quantity, 10000);
      expect(draft.unit.length, lessThanOrEqualTo(20));
    });
  });

  group('ShoppingController.addItems', () {
    test('counts new and merged items', () async {
      final repository = FakeShoppingRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(shoppingControllerProvider);

      await controller.addItems('list-1', const [
        ShoppingItemDraft(name: 'Trứng', quantity: 6, unit: 'quả'),
      ]);
      final result = await controller.addItems('list-1', const [
        ShoppingItemDraft(name: 'Trứng', quantity: 4, unit: 'quả'),
        ShoppingItemDraft(name: 'Hành lá', quantity: 1, unit: 'bó'),
      ]);

      expect(result.added, 1);
      expect(result.merged, 1);
      expect(result.failedNames, isEmpty);
    });

    test('reports invalid items without stopping the others', () async {
      final repository = FakeShoppingRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final result = await container
          .read(shoppingControllerProvider)
          .addItems('list-1', const [
            ShoppingItemDraft(name: 'Muối', quantity: 0, unit: 'gói'),
            ShoppingItemDraft(name: 'Đường', quantity: 1, unit: 'gói'),
          ]);

      expect(result.added, 1);
      expect(result.failedNames, ['Muối']);
    });
  });

  testWidgets('sheet adds only the ticked ingredients to the chosen list', (
    tester,
  ) async {
    final repository = FakeShoppingRepository()
      ..lists = [
        ShoppingList(
          id: 'list-1',
          householdId: 'home-1',
          name: 'Đi chợ cuối tuần',
          createdBy: 'user-1',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      ];
    await _pumpSheet(tester, repository);

    expect(find.text('Đi chợ cuối tuần'), findsOneWidget);
    expect(find.text('Thêm (2) món'), findsOneWidget);

    await tester.tap(find.text('Hành lá'));
    await tester.pump();
    expect(find.text('Thêm (1) món'), findsOneWidget);

    await tester.tap(find.text('Thêm (1) món'));
    await tester.pumpAndSettle();

    final added = repository.addedItems.single.draft;
    expect(added.name, 'Cá lóc');
    expect(added.source, ShoppingItemSource.aiRecipe);
  });

  testWidgets('sheet offers a new list when the household has none', (
    tester,
  ) async {
    await _pumpSheet(tester, FakeShoppingRepository());

    expect(find.text('+ Tạo danh sách mới'), findsOneWidget);
    expect(find.text('Nấu Canh chua'), findsOneWidget);
  });
}

final _user = User(
  id: 'user-1',
  fullName: 'An',
  email: 'an@example.com',
  activeHouseholdId: 'home-1',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container(FakeShoppingRepository repository) =>
    ProviderContainer(
      overrides: [
        shoppingRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(_user),
      ],
    );

Future<void> _pumpSheet(
  WidgetTester tester,
  FakeShoppingRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shoppingRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(_user),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AddRecipeToShoppingSheet(
                recipeTitle: 'Canh chua',
                ingredients: [
                  RecipeShoppingIngredient(
                    name: 'Cá lóc',
                    quantity: 1,
                    unit: 'con',
                  ),
                  RecipeShoppingIngredient(name: 'Hành lá'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
