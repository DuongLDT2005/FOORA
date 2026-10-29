import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../shared/components/app_bottom_bar.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/create_edit_shopping_list_sheet.dart';
import '../widgets/shopping_list_card.dart';

/// All shopping lists of the active household, shared in real time.
class ShoppingListsPage extends ConsumerWidget {
  const ShoppingListsPage({super.key});

  Future<void> _createList(BuildContext context) async {
    final listId = await CreateEditShoppingListSheet.show(context);
    if (listId != null && context.mounted) {
      context.push(AppRouteNames.shoppingListDetailPath(listId));
    }
  }

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa danh sách mua sắm',
      message: 'Xóa danh sách "${list.name}" và toàn bộ món trong đó?',
    );
    if (confirmed != true) return;
    try {
      await ref.read(shoppingControllerProvider).deleteList(list.id);
      if (context.mounted) ToastHelper.show(context, 'Đã xóa danh sách');
    } catch (e) {
      if (context.mounted) {
        ToastHelper.show(context, shoppingErrorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(shoppingListsStreamProvider);

    return SubpageLayout(
      header: AppHeader(
        title: 'Danh sách mua sắm',
        onBack: () => context.pop(),
      ),
      bottomBar: AppBottomBar(
        child: AppButton.primary(
          label: 'Tạo danh sách',
          icon: LucideIcons.plus,
          onPressed: () => _createList(context),
        ),
      ),
      body: listsAsync.when(
        loading: () => const LoadingWidget(message: 'Đang tải danh sách...'),
        error: (e, _) => ErrorStateWidget(
          message: shoppingErrorMessage(e),
          onRetry: () => ref.invalidate(shoppingListsStreamProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return const EmptyStateWidget(
              title: 'Chưa có danh sách mua sắm',
              subtitle:
                  'Tạo danh sách để lên kế hoạch đi chợ cùng các thành viên '
                  'trong gia đình. Bạn có thể thêm món bằng giọng nói.',
            );
          }
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ShoppingListCard(
                shoppingList: list,
                onTap: () => context.push(
                  AppRouteNames.shoppingListDetailPath(list.id),
                  extra: list,
                ),
                onRename: () =>
                    CreateEditShoppingListSheet.show(context, listToEdit: list),
                onDelete: () => _deleteList(context, ref, list),
              );
            },
          );
        },
      ),
    );
  }
}
