import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_recipe.dart';
import 'ai_entry_receipt_card.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onReviewActions});

  final AiChatMessage message;
  final VoidCallback? onReviewActions;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 320.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 14.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18.r),
                border: isUser ? null : Border.all(color: AppColors.slate200),
              ),
              child: SelectableText(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 15.sp,
                  height: 1.5,
                  color: isUser
                      ? AppColors.surfaceContainerLowest
                      : AppColors.slate800,
                ),
              ),
            ),
            ...message.recipes.map((recipe) => _RecipeCard(recipe: recipe)),
            if (message.actions.isNotEmpty &&
                message.actions.every(
                  (action) => action.type == 'add_inventory',
                ))
              AiEntryReceiptCard(message: message, onEdit: onReviewActions)
            else if (message.actions.isNotEmpty)
              _ActionSummary(
                message: message,
                onReviewActions: onReviewActions,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionSummary extends StatelessWidget {
  const _ActionSummary({required this.message, this.onReviewActions});

  final AiChatMessage message;
  final VoidCallback? onReviewActions;

  @override
  Widget build(BuildContext context) {
    final pending = message.actionStatus == 'proposed';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đề xuất cập nhật kho',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.slate800,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 8.h),
          ...message.actions.map(
            (action) => Padding(
              padding: EdgeInsets.only(bottom: 5.h),
              child: Text(
                '${action.name}: ${action.type} · '
                '${action.resolution == 'pending' ? action.reviewState : action.resolution}',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ),
          if (pending)
            TextButton(
              onPressed: onReviewActions,
              child: const Text('Xem và xác nhận'),
            ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final AiRecipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.slate800,
              fontSize: 16.sp,
            ),
          ),
          if (recipe.cookingMinutes != null)
            Text('${recipe.cookingMinutes} phút', style: AppTextStyles.caption),
          if (recipe.usedIngredients.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              'Trong tủ: ${recipe.usedIngredients.join(', ')}',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (recipe.missingIngredients.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Cần thêm: ${recipe.missingIngredients.join(', ')}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.red700),
            ),
          ],
          SizedBox(height: 10.h),
          ...recipe.steps.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: 5.h),
              child: Text(
                '${entry.key + 1}. ${entry.value}',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
