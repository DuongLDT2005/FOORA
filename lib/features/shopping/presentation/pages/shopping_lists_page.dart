import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/helpers/dialog_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../../domain/entities/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/create_edit_shopping_list_sheet.dart';
import '../widgets/shopping_list_card.dart';

class ShoppingListsPage extends ConsumerWidget {
  const ShoppingListsPage({super.key});

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final confirmed = await DialogHelper.showDeleteDialog(
      context,
      title: 'Xóa danh sách mua sắm',
      message:
          'Bạn có chắc muốn xóa danh sách "${list.name}" và toàn bộ các món trong danh sách này?',
    );

    if (confirmed == true) {
      try {
        await ref
            .read(shoppingControllerProvider.notifier)
            .deleteShoppingList(list.id);
        if (context.mounted) {
          ToastHelper.show(context, 'Đã xóa danh sách mua sắm');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.show(context, 'Lỗi khi xóa: $e', isError: true);
        }
      }
    }
  }

  Future<void> _createNewList(BuildContext context) async {
    final newListId = await CreateEditShoppingListSheet.show(context);
    if (newListId != null && context.mounted) {
      context.push(
        AppRouteNames.shoppingListDetail.replaceFirst(':id', newListId),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final householdAsync = ref.watch(currentHouseholdStreamProvider);
    final household = householdAsync.valueOrNull;

    debugPrint('🔍 [ShoppingListsPage] User: ${user?.id}, Household: ${household?.id}, Owner: ${household?.ownerId}, Members: ${household?.members}');

    if (householdAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Danh sách mua sắm',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamilyHeadline,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        body: const LoadingWidget(message: 'Đang tải thông tin gia đình...'),
      );
    }

    if (household == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Danh sách mua sắm',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamilyHeadline,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
              color: AppColors.slate800,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyStateWidget(
                  title: 'Chưa có thông tin gia đình',
                  subtitle:
                      'Bạn cần tạo hoặc tham gia một gia đình để sử dụng tính năng Danh sách mua sắm.',
                ),
                SizedBox(height: 20.h),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRouteNames.household),
                  icon: const Icon(LucideIcons.users),
                  label: const Text('Đến trang Quản lý gia đình'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listsAsync = ref.watch(activeHouseholdShoppingListsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Danh sách mua sắm',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamilyHeadline,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      body: listsAsync.when(
        loading: () => const LoadingWidget(message: 'Đang tải danh sách mua sắm...'),
        error: (err, stack) => ErrorStateWidget(
          message: 'Không thể tải danh sách mua sắm: $err',
          onRetry: () => ref.invalidate(activeHouseholdShoppingListsStreamProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyStateWidget(
                      title: 'Chưa có danh sách mua sắm',
                      subtitle:
                          'Tạo danh sách để lên kế hoạch mua thực phẩm cùng các thành viên trong gia đình.',
                    ),
                    SizedBox(height: 20.h),
                    ElevatedButton.icon(
                      onPressed: () => _createNewList(context),
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('Tạo danh sách đầu tiên'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ShoppingListCard(
                shoppingList: list,
                onTap: () {
                  context.push(
                    AppRouteNames.shoppingListDetail.replaceFirst(':id', list.id),
                    extra: list,
                  );
                },
                onRename: () => CreateEditShoppingListSheet.show(context, listToEdit: list),
                onDelete: () => _deleteList(context, ref, list),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewList(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(
          'Tạo danh sách',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
