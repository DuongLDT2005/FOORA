import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_shimmer.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/entities/shopping_suggestion.dart';
import '../providers/shopping_providers.dart';
import 'add_edit_shopping_item_sheet.dart';
import 'shopping_item_tile.dart';
import 'shopping_section_title.dart';

/// "Gợi ý hay mua" row on a list page. Hidden when there is nothing to
/// suggest; errors show a small retry line without blocking the list.
class FrequentSuggestionsSection extends ConsumerWidget {
  final String listId;

  const FrequentSuggestionsSection({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(shoppingSuggestionsProvider);

    return suggestionsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: AppShimmer.box(
          width: double.infinity,
          height: 112.h,
          borderRadius: 16.r,
        ),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Không tải được gợi ý hay mua.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.slate500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(shoppingSuggestionsProvider),
              child: const AppButtonLabel('Thử lại'),
            ),
          ],
        ),
      ),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShoppingSectionTitle(title: 'Gợi ý hay mua'),
              SizedBox(
                height: 150.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => SizedBox(width: 10.w),
                  itemBuilder: (context, index) => FrequentSuggestionCard(
                    suggestion: suggestions[index],
                    onAdd: () => AddEditShoppingItemSheet.show(
                      context,
                      listId: listId,
                      initialDraft: _draftFrom(suggestions[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static ShoppingItemDraft _draftFrom(ShoppingSuggestion s) {
    return ShoppingItemDraft(
      name: s.name,
      quantity: s.quantity,
      unit: s.unit,
      foodId: s.foodId,
      categoryId: s.categoryId.isEmpty ? null : s.categoryId,
      source: ShoppingItemSource.suggestion,
    );
  }
}

class FrequentSuggestionCard extends StatelessWidget {
  final ShoppingSuggestion suggestion;
  final VoidCallback onAdd;

  const FrequentSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = suggestion.stockState == ShoppingStockState.out;
    final pillRadius = BorderRadius.circular(22.r);

    return Container(
      width: 230.w,
      padding: EdgeInsets.all(14.r),
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
                  suggestion.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isOut ? AppColors.red50 : AppColors.amber50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOut ? 'Đã hết' : 'Sắp hết',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamilySans,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isOut ? AppColors.red600 : AppColors.amber700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Expanded(
            child: Text(
              suggestion.reason,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamilySans,
                fontSize: 12.sp,
                color: AppColors.slate500,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: pillRadius,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: InkWell(
              borderRadius: pillRadius,
              onTap: onAdd,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.plus,
                      size: 15.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: AppButtonLabel(
                        'Thêm ${formatShoppingQuantity(suggestion.quantity)} '
                        '${suggestion.unit}',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamilySans,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
