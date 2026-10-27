import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../inventory/domain/entities/inventory_item.dart';
import '../../domain/entities/ai_chat_message.dart';

/// Quick replies under the latest answer, chosen from what it contains. A
/// receipt is its own next step, so it gets none.
List<String> aiFollowUps(AiChatMessage message) {
  if (message.isUser || message.actions.isNotEmpty) return const [];
  if (message.recipes.isNotEmpty) {
    final servings = message.recipes.first.servings;
    return [
      'Gợi ý món khác',
      'Món nào nấu nhanh hơn?',
      servings == 4 ? 'Điều chỉnh cho 2 người' : 'Điều chỉnh cho 4 người',
    ];
  }
  if (message.content.toLowerCase().contains('hạn')) {
    return const ['Nấu gì với những món này?', 'Món nào nên dùng trước?'];
  }
  return const ['Nấu gì với đồ sắp hết hạn?', 'Tủ còn gì sắp hết hạn?'];
}

/// Starter questions built from the fridge, nearest expiry first, so the
/// first tap already asks about the user's own food.
List<String> aiWelcomeSuggestions(List<InventoryItem> items, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final usable =
      items
          .where(
            (item) =>
                item.status == InventoryItemStatus.active &&
                item.quantity > 0 &&
                !DateUtils.dateOnly(item.expirationDate).isBefore(today),
          )
          .toList()
        ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
  if (usable.isEmpty) {
    return const [
      'Trong tủ còn thực phẩm nào sắp hết hạn?',
      'Tôi vừa mua 1 kg thịt gà và 2 bó rau cải',
      'Gợi ý món ăn cho 2 người tối nay',
    ];
  }
  final first = usable.first;
  final names = usable.map((item) => item.name).toSet().take(2).toList();
  final amount = const {'g', 'ml'}.contains(first.unit.toLowerCase()) ? 100 : 1;
  return [
    'Trong tủ còn thực phẩm nào sắp hết hạn?',
    'Nấu gì với ${names.join(' và ')}?',
    '${first.name} ${aiExpiryLabel(first.expirationDate, now)}, '
        'nên dùng thế nào?',
    'Tôi đã dùng $amount ${first.unit} ${first.name}',
  ];
}

/// "hết hạn hôm nay" / "hết hạn ngày mai" / "còn N ngày" / "đã quá hạn".
String aiExpiryLabel(DateTime expirationDate, DateTime now) {
  final days = DateUtils.dateOnly(
    expirationDate,
  ).difference(DateUtils.dateOnly(now)).inDays;
  if (days < 0) return 'đã quá hạn';
  if (days == 0) return 'hết hạn hôm nay';
  if (days == 1) return 'hết hạn ngày mai';
  return 'còn $days ngày';
}

/// Tappable quick replies; each one is sent as soon as it is tapped.
class AiFollowUpChips extends StatelessWidget {
  const AiFollowUpChips({
    super.key,
    required this.questions,
    required this.onSelected,
  });

  final List<String> questions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final question in questions)
            ActionChip(
              label: Text(question),
              onPressed: () => onSelected(question),
              backgroundColor: AppColors.surfaceContainerLowest,
              side: const BorderSide(color: AppColors.slate200),
              labelStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
        ],
      ),
    );
  }
}
