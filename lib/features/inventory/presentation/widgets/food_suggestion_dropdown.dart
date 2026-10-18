import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/food_suggestion.dart';

/// Floating autocomplete card listing up to [maxItems] food suggestions
/// (master catalogue or household history) under the name field.
class FoodSuggestionDropdown extends StatelessWidget {
  const FoodSuggestionDropdown({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.maxItems = 5,
  });

  final List<FoodSuggestion> suggestions;
  final ValueChanged<FoodSuggestion> onSelected;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final visible = suggestions.take(maxItems).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440.w),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < visible.length; i++)
                _SuggestionTile(
                  suggestion: visible[i],
                  isLast: i == visible.length - 1,
                  onTap: () => onSelected(visible[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.isLast,
    required this.onTap,
  });

  final FoodSuggestion suggestion;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alias = suggestion.matchedAlias;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.slate100)),
        ),
        child: Row(
          children: [
            Icon(
              suggestion.isFromMaster
                  ? LucideIcons.sparkles
                  : LucideIcons.history,
              size: 16.r,
              color: suggestion.isFromMaster
                  ? AppColors.primary
                  : AppColors.slate400,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                  if (alias != null && alias.isNotEmpty)
                    Text(
                      'Tên khác: $alias',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 11.sp,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            if (suggestion.defaultUnit.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Text(
                  suggestion.defaultUnit,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
