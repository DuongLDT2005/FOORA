import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/services/ai_food_category.dart';
import '../providers/ai_provider.dart';

class AiConsumeReceiptCard extends ConsumerStatefulWidget {
  const AiConsumeReceiptCard({super.key, required this.message, this.onEdit});

  final AiChatMessage message;
  final VoidCallback? onEdit;

  @override
  ConsumerState<AiConsumeReceiptCard> createState() =>
      _AiConsumeReceiptCardState();
}

class _AiConsumeReceiptCardState extends ConsumerState<AiConsumeReceiptCard> {
  final Map<String, String> _categories = {};
  List<Map<String, dynamic>>? _retryDecisions;
  bool _sending = false;
  String? _error;

  String? _categoryId(AiAction action) =>
      _categories[action.actionId] ??
      action.categoryId ??
      suggestAiCategoryId(action.name);

  String _amount(AiAction action) {
    final quantity = action.quantity;
    if (quantity == null || quantity <= 0) return 'Dùng hết';
    final number = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$number ${action.unit ?? ''}'.trim();
  }

  Future<void> _confirm() async {
    if (_sending || widget.message.actionStatus != 'proposed') return;
    final decisions = <Map<String, dynamic>>[];
    for (final action in widget.message.actions) {
      final decision = <String, dynamic>{
        'actionId': action.actionId,
        'accept': true,
      };
      if (action.targetItemId != null && action.targetItemId!.isNotEmpty) {
        decision['targetItemId'] = action.targetItemId;
      } else if (action.candidateBatches.isNotEmpty) {
        decision['targetItemId'] = action.candidateBatches.first.itemId;
      }
      final qty = action.quantity ??
          (action.candidateBatches.isNotEmpty
              ? action.candidateBatches.first.quantity
              : null);
      if (qty != null && qty > 0) {
        decision['quantity'] = qty;
      }
      final unit = action.unit ??
          (action.candidateBatches.isNotEmpty
              ? action.candidateBatches.first.unit
              : null);
      if (unit != null && unit.isNotEmpty) {
        decision['unit'] = unit;
      }
      decisions.add(decision);
    }
    final payload = _retryDecisions ?? decisions;
    _retryDecisions = payload;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(applyAiActionsProvider)(
        messageId: widget.message.id,
        decisions: payload,
      );
      ref.invalidate(aiChatHistoryProvider);
      ref.invalidate(activeHouseholdInventoryStreamProvider);
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể trừ kho. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(foodCategoriesProvider);
    final categories = categoryAsync.valueOrNull ?? [];
    final pending = widget.message.actionStatus == 'proposed';
    final canConfirm = widget.message.actions.every((action) {
      return action.name.trim().isNotEmpty;
    });

    final locationIds = widget.message.actions
        .map((action) => action.storageLocationId)
        .whereType<String>()
        .toSet();
    final locationLabel = locationIds.isEmpty
        ? 'Tủ lạnh'
        : locationIds.length > 1
        ? 'Nhiều vị trí'
        : locationIds.single == 'freezer'
        ? 'Ngăn đông'
        : 'Ngăn mát';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
              Expanded(
                child: Text(
                  'Phiếu trừ tủ lạnh',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${widget.message.actions.length} món',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            locationLabel,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
          ),
          SizedBox(height: 14.h),
          for (
            var index = 0;
            index < widget.message.actions.length;
            index++
          ) ...[
            if (index > 0) Divider(height: 17.h, color: AppColors.slate100),
            _buildLine(widget.message.actions[index], categories, pending),
          ],
          SizedBox(height: 14.h),
          Text(
            pending
                ? 'Chưa trừ kho · Kiểm tra rồi xác nhận'
                : widget.message.actionStatus == 'applied'
                ? 'Đã trừ kho'
                : 'Phiếu không còn hiệu lực',
            style: AppTextStyles.bodySmall.copyWith(
              color: widget.message.actionStatus == 'applied'
                  ? AppColors.primary
                  : AppColors.slate600,
              fontWeight: widget.message.actionStatus == 'applied'
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.red700),
            ),
          ],
          if (pending) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canConfirm && !_sending ? _confirm : null,
                child: Text(_sending ? 'Đang trừ kho…' : 'Xác nhận trừ kho'),
              ),
            ),
            if (widget.onEdit != null)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: widget.onEdit,
                  child: const Text('Sửa tên, lượng hoặc chọn lô'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLine(
    AiAction action,
    List<FoodCategory> categories,
    bool pending,
  ) {
    final categoryId = _categoryId(action);
    FoodCategory? category;
    for (final candidate in categories) {
      if (candidate.id == categoryId) {
        category = candidate;
        break;
      }
    }
    final categoryLabel = category?.name ?? 'Thịt';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                action.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.slate800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              _amount(action),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.slate800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (pending && categories.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'Danh mục ${action.name}',
            padding: EdgeInsets.zero,
            onSelected: (value) => setState(() {
              _categories[action.actionId] = value;
              _retryDecisions = null;
              _error = null;
            }),
            itemBuilder: (_) => categories
                .map(
                  (candidate) => PopupMenuItem(
                    value: candidate.id,
                    child: Text(candidate.name),
                  ),
                )
                .toList(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    categoryLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: category == null
                          ? AppColors.slate600
                          : AppColors.slate600,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18.r,
                    color: AppColors.slate600,
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              categoryLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
              ),
            ),
          ),
      ],
    );
  }
}
