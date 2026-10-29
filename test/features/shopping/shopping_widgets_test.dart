import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/shopping/domain/entities/shopping_item.dart';
import 'package:foora/features/shopping/domain/entities/shopping_list.dart';
import 'package:foora/features/shopping/domain/entities/shopping_suggestion.dart';
import 'package:foora/features/shopping/presentation/pages/shopping_list_detail_page.dart';
import 'package:foora/features/shopping/presentation/pages/shopping_lists_page.dart';
import 'package:foora/features/shopping/presentation/providers/shopping_providers.dart';
import 'package:foora/features/shopping/presentation/widgets/frequent_suggestions_section.dart';

import 'fake_shopping_repository.dart';

void main() {
  late FakeShoppingRepository repository;

  setUp(() => repository = FakeShoppingRepository());

  testWidgets('lists page shows the empty state', (tester) async {
    await _pump(tester, repository, const ShoppingListsPage());

    expect(find.text('Chưa có danh sách mua sắm'), findsOneWidget);
    expect(find.text('Tạo danh sách'), findsOneWidget);
  });

  testWidgets('two purchased items offer "Nhập kho (2)"', (tester) async {
    repository.lists = [_list];
    repository.seedItems([
      _item('a', 'Sữa tươi', isPurchased: true),
      _item('b', 'Trứng gà', isPurchased: true),
      _item('c', 'Cà chua'),
    ]);

    await _pump(
      tester,
      repository,
      const ShoppingListDetailPage(listId: 'list-1'),
    );

    expect(find.text('CẦN MUA (1)'), findsOneWidget);
    expect(find.text('ĐÃ MUA (2)'), findsOneWidget);
    expect(find.text('Nhập kho (2)'), findsOneWidget);
  });

  testWidgets('suggestion card shows its reason', (tester) async {
    repository.suggestions = const [
      ShoppingSuggestion(
        key: 'milk',
        name: 'Sữa tươi',
        categoryId: 'dairy',
        quantity: 2,
        unit: 'hộp',
        avgIntervalDays: 7,
        daysSinceLastPurchase: 8,
        purchaseCount: 3,
        stockState: ShoppingStockState.out,
        reason:
            'Bạn thường mua Sữa tươi mỗi ~7 ngày, lần cuối 8 ngày trước, '
            'đã hết trong tủ.',
      ),
    ];

    await _pump(
      tester,
      repository,
      const Scaffold(body: FrequentSuggestionsSection(listId: 'list-1')),
    );

    expect(find.text('GỢI Ý HAY MUA'), findsOneWidget);
    expect(find.textContaining('mỗi ~7 ngày'), findsOneWidget);
  });
}

final _list = ShoppingList(
  id: 'list-1',
  householdId: 'home-1',
  name: 'Đi chợ cuối tuần',
  createdBy: 'user-1',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

ShoppingItem _item(String id, String name, {bool isPurchased = false}) {
  return ShoppingItem(
    id: id,
    shoppingListId: 'list-1',
    name: name,
    normalizedName: name.toLowerCase(),
    quantity: 1,
    unit: 'hộp',
    isPurchased: isPurchased,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );
}

Future<void> _pump(
  WidgetTester tester,
  FakeShoppingRepository repository,
  Widget child,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shoppingRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(
          User(
            id: 'user-1',
            fullName: 'An',
            email: 'an@example.com',
            activeHouseholdId: 'home-1',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
