import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_recipe.dart';
import 'ai_chat_suggestions.dart' show aiExpiryLabel;
import 'ai_consume_receipt_card.dart';
import 'ai_entry_receipt_card.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onReviewActions,
    this.onCooked,
  });

  final AiChatMessage message;
  final VoidCallback? onReviewActions;

  /// Starts a "I cooked this" report the user edits before sending.
  final ValueChanged<AiRecipe>? onCooked;

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
            ...message.recipes.map(
              (recipe) => _RecipeCard(
                recipe: recipe,
                onCooked: onCooked == null ? null : () => onCooked!(recipe),
              ),
            ),
            if (message.actions.isNotEmpty &&
                message.actions.every(
                  (action) => action.type == 'add_inventory',
                ))
              AiEntryReceiptCard(message: message, onEdit: onReviewActions)
            else if (message.actions.isNotEmpty)
              AiConsumeReceiptCard(message: message, onEdit: onReviewActions),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, this.onCooked});

  final AiRecipe recipe;
  final VoidCallback? onCooked;

  @override
  Widget build(BuildContext context) {
    final inStock = recipe.ingredients.where((item) => item.inInventory);
    final toBuy = recipe.ingredients.where((item) => !item.inInventory);
    // The backend lists the part above the stock again under "to buy".
    final stockedNames = {for (final item in inStock) item.name};
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                size: 18.r,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  recipe.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (recipe.servings != null)
                Text(
                  '${recipe.servings} người',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate600,
                  ),
                ),
            ],
          ),
          if (inStock.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _sectionLabel('Có trong tủ', AppColors.primary),
            ...inStock.map(_ingredientLine),
          ],
          if (toBuy.isNotEmpty) ...[
            SizedBox(height: 10.h),
            _sectionLabel('Cần mua thêm', AppColors.amber800),
            ...toBuy.map(
              (item) => _ingredientLine(
                item,
                note: stockedNames.contains(item.name)
                    ? 'Tủ không đủ, cần mua thêm'
                    : null,
              ),
            ),
          ],
          SizedBox(height: 4.h),
          Divider(height: 12.h, color: AppColors.slate100),
          Wrap(
            spacing: 4.w,
            children: [
              // The assistant lists amounts only; steps come from a search.
              TextButton.icon(
                onPressed: () => _openCookingSearch(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                ),
                icon: Icon(Icons.play_circle_outline_rounded, size: 18.r),
                label: const Text('Xem cách nấu'),
              ),
              if (onCooked != null && inStock.isNotEmpty)
                TextButton.icon(
                  onPressed: onCooked,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                  ),
                  icon: Icon(Icons.check_circle_outline_rounded, size: 18.r),
                  label: const Text('Tôi đã nấu món này'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCookingSearch(BuildContext context) async {
    final url = Uri.https('www.youtube.com', '/results', {
      'search_query': 'cách nấu ${recipe.title}',
    });
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Reported below like an app that declined the link.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trang hướng dẫn nấu.')),
      );
    }
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: EdgeInsets.only(bottom: 4.h),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );

  /// Why the dish was picked: fridge items expiring within two days stand out.
  Widget _expiryLabel(DateTime expirationDate) {
    final now = DateTime.now();
    final soon = !DateUtils.dateOnly(
      expirationDate,
    ).isAfter(DateUtils.dateOnly(now).add(const Duration(days: 2)));
    return Text(
      aiExpiryLabel(expirationDate, now),
      style: AppTextStyles.caption.copyWith(
        fontSize: 11.sp,
        color: soon ? AppColors.amber800 : AppColors.slate500,
        fontWeight: soon ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _ingredientLine(AiRecipeIngredient ingredient, {String? note}) {
    final quantity = ingredient.quantity;
    final amount = quantity == null
        ? ''
        : '${aiDisplayNumber(quantity)} ${ingredient.unit ?? ''}'.trim();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate800,
                  ),
                ),
                if (ingredient.inInventory && ingredient.expirationDate != null)
                  _expiryLabel(ingredient.expirationDate!),
                if (note != null)
                  Text(
                    note,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.amber800,
                    ),
                  ),
              ],
            ),
          ),
          if (amount.isNotEmpty) ...[
            SizedBox(width: 12.w),
            Text(
              amount,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
