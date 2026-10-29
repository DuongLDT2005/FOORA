import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_bottom_bar.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/add_edit_shopping_item_sheet.dart';
import '../widgets/add_mode_sheet.dart';
import '../widgets/batch_import_inventory_sheet.dart';
import '../widgets/create_edit_shopping_list_sheet.dart';
import '../widgets/frequent_suggestions_section.dart';
import '../widgets/shopping_item_tile.dart';
import '../widgets/shopping_section_title.dart';
import '../widgets/voice_add_sheet.dart';

enum _ListAction { rename, delete }

/// One shopping list: suggestions, items to buy, purchased items and the
/// "move into the fridge" action.
class ShoppingListDetailPage extends ConsumerWidget {
  final String listId;
  final ShoppingList? initialList;

  const ShoppingListDetailPage({
    super.key,
    required this.listId,
    this.initialList,
  });

  Future<void> _chooseAddMode(BuildContext context) async {
    final mode = await AddModeSheet.show(context);
    if (!context.mounted) return;
    switch (mode) {
      case ShoppingAddMode.manual:
        await AddEditShoppingItemSheet.show(context, listId: listId);
      case ShoppingAddMode.voice:
        await VoiceAddSheet.show(context, listId: listId);
      case null:
        break;
    }
  }

  Future<void> _onListAction(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
    _ListAction action,
  ) async {
    if (action == _ListAction.rename) {
      await CreateEditShoppingListSheet.show(context, listToEdit: list);
      return;
    }
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa danh sách mua sắm',
      message: 'Xóa danh sách "${list.name}" và toàn bộ món trong đó?',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(shoppingControllerProvider).deleteList(list.id);
      if (context.mounted) {
        ToastHelper.show(context, 'Đã xóa danh sách');
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.show(context, shoppingErrorMessage(e), isError: true);
      }
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ToastHelper.show(context, shoppingErrorMessage(e), isError: true);
      }
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa món cần mua',
      message: 'Xóa "${item.name}" khỏi danh sách?',
    );
    if (confirmed == true && context.mounted) {
      await _run(
        context,
        () => ref.read(shoppingControllerProvider).deleteItem(item),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(shoppingListStreamProvider(listId)).valueOrNull ??
        initialList;
    final itemsAsync = ref.watch(shoppingItemsStreamProvider(listId));
    final items = itemsAsync.valueOrNull ?? const <ShoppingItem>[];
    final toImport = items.where((i) => i.canAddToInventory).toList();

    return SubpageLayout(
      header: AppHeader(
        title: list?.name ?? 'Danh sách mua sắm',
        onBack: () => context.pop(),
        trailing: list == null
            ? null
            : ShoppingHeaderMenuButton<_ListAction>(
                onSelected: (a) => _onListAction(context, ref, list, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _ListAction.rename,
                    child: Text('Đổi tên danh sách'),
                  ),
                  PopupMenuItem(
                    value: _ListAction.delete,
                    child: Text(
                      'Xóa danh sách',
                      style: TextStyle(color: AppColors.red500),
                    ),
                  ),
                ],
              ),
      ),
      // Two buttons share the bar, so icons are dropped to keep labels on
      // one line.
      bottomBar: AppBottomBar(
        child: toImport.isEmpty
            ? AppButton.primary(
                label: 'Thêm món',
                icon: LucideIcons.plus,
                onPressed: () => _chooseAddMode(context),
              )
            : Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Thêm món',
                      onPressed: () => _chooseAddMode(context),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Nhập kho (${toImport.length})',
                      onPressed: () => BatchImportInventorySheet.show(
                        context,
                        listId: listId,
                        candidateItems: toImport,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      body: itemsAsync.when(
        loading: () => const LoadingWidget(message: 'Đang tải các món...'),
        error: (e, _) => ErrorStateWidget(
          message: shoppingErrorMessage(e),
          onRetry: () => ref.invalidate(shoppingItemsStreamProvider(listId)),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(shoppingSuggestionsProvider),
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            children: [
              FrequentSuggestionsSection(listId: listId),
              if (items.isEmpty)
                const EmptyStateWidget(
                  title: 'Danh sách trống',
                  subtitle:
                      'Bấm "Thêm món" để nhập tay hoặc nói, ví dụ "2 hộp sữa '
                      'và 6 quả trứng".',
                )
              else
                ..._buildSections(context, ref, items),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItem> items,
  ) {
    final toBuy = items.where((i) => !i.isPurchased).toList();
    final purchased = items.where((i) => i.isPurchased).toList();
    final controller = ref.read(shoppingControllerProvider);

    Widget tile(ShoppingItem item) => ShoppingItemTile(
      item: item,
      onTogglePurchased: (value) =>
          _run(context, () => controller.setPurchased(item, value)),
      onEdit: () => AddEditShoppingItemSheet.show(
        context,
        listId: listId,
        itemToEdit: item,
      ),
      onDelete: () => _deleteItem(context, ref, item),
    );

    return [
      _ProgressHeader(purchased: purchased.length, total: items.length),
      SizedBox(height: 20.h),
      if (toBuy.isNotEmpty) ...[
        ShoppingSectionTitle(title: 'Cần mua', count: toBuy.length),
        ...toBuy.map(tile),
        SizedBox(height: 10.h),
      ],
      if (purchased.isNotEmpty) ...[
        ShoppingSectionTitle(title: 'Đã mua', count: purchased.length),
        ...purchased.map(tile),
      ],
    ];
  }
}

class _ProgressHeader extends StatelessWidget {
  final int purchased;
  final int total;

  const _ProgressHeader({required this.purchased, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : purchased / total;
    final isDone = total > 0 && purchased == total;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiến độ mua sắm',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
              ),
              Text(
                '$purchased/$total món',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamilySans,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: isDone ? AppColors.primary : AppColors.slate700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8.h,
              backgroundColor: AppColors.slate100,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
