import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import 'ai_entry_receipt_card.dart' show aiDisplayDate;

/// Inline receipt for consume/discard proposals. Confirming sends only the
/// decision: the server applies the proposed amount and splits it over the
/// candidate batches by FEFO. Proposals that need review must be completed
/// in the review sheet first (PLAN_04 §2.1, §5).
class AiConsumeReceiptCard extends ConsumerStatefulWidget {
  const AiConsumeReceiptCard({super.key, required this.message, this.onEdit});

  final AiChatMessage message;
  final VoidCallback? onEdit;

  @override
  ConsumerState<AiConsumeReceiptCard> createState() =>
      _AiConsumeReceiptCardState();
}

class _AiConsumeReceiptCardState extends ConsumerState<AiConsumeReceiptCard> {
  bool _sending = false;
  String? _error;

  String _amount(AiAction action) {
    final quantity = action.quantity;
    if (quantity == null) return 'Chưa rõ lượng';
    final number = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$number ${action.unit ?? ''}'.trim();
  }

  Future<void> _confirm() async {
    if (_sending || widget.message.actionStatus != 'proposed') return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(applyAiActionsProvider)(
        messageId: widget.message.id,
        decisions: [
          for (final action in widget.message.actions)
            {'actionId': action.actionId, 'accept': true},
        ],
      );
      ref.invalidate(aiChatHistoryProvider);
      ref.invalidate(activeHouseholdInventoryStreamProvider);
    } on Failure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể cập nhật kho. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.message.actions;
    final pending = widget.message.actionStatus == 'proposed';
    final applied = widget.message.actionStatus == 'applied';
    final needsReview = actions.any((action) => action.reviewState != 'ready');
    final discardOnly = actions.every((action) => action.type == 'discard');

    final endsWithLink = pending && widget.onEdit != null && !needsReview;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      // The edit link carries its own padding below.
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, endsWithLink ? 6.h : 16.h),
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
                  discardOnly ? 'Phiếu bỏ thực phẩm' : 'Phiếu trừ tủ lạnh',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate800,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${actions.length} món',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) Divider(height: 17.h, color: AppColors.slate100),
            _buildLine(actions[index], pending),
          ],
          SizedBox(height: 14.h),
          Text(
            !pending
                ? applied
                      ? 'Đã cập nhật kho'
                      : 'Phiếu không còn hiệu lực'
                : needsReview
                ? 'Cần bổ sung thông tin trước khi cập nhật kho'
                : 'Chưa cập nhật kho · Kiểm tra rồi xác nhận',
            style: AppTextStyles.bodySmall.copyWith(
              color: applied
                  ? AppColors.primary
                  : pending && needsReview
                  ? AppColors.amber800
                  : AppColors.slate600,
              fontWeight: applied ? FontWeight.w600 : FontWeight.normal,
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
            if (!needsReview)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sending ? null : _confirm,
                  child: Text(
                    _sending ? 'Đang cập nhật kho…' : 'Xác nhận cập nhật kho',
                  ),
                ),
              ),
            if (widget.onEdit != null) ...[
              if (!needsReview) SizedBox(height: 4.h),
              SizedBox(
                width: double.infinity,
                child: needsReview
                    ? FilledButton(
                        onPressed: widget.onEdit,
                        child: const Text('Kiểm tra và chọn lô'),
                      )
                    : TextButton(
                        onPressed: widget.onEdit,
                        child: const Text('Sửa lượng hoặc chọn lô'),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLine(AiAction action, bool pending) {
    final batches = [...action.candidateBatches]
      ..sort(
        (a, b) =>
            (a.expirationDate ?? '9999').compareTo(b.expirationDate ?? '9999'),
      );
    final detail = [
      if (action.type == 'discard') 'Bỏ đi',
      if (batches.length > 1)
        'Trừ dần từ ${batches.length} lô, lô gần hết hạn trước'
      else if (batches.isNotEmpty && batches.first.expirationDate != null)
        'Lô HSD ${aiDisplayDate(batches.first.expirationDate!)}',
    ].join(' · ');
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
                color: action.quantity == null
                    ? AppColors.amber800
                    : AppColors.slate800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (detail.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              detail,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
              ),
            ),
          ),
        if (pending && action.reviewState != 'ready')
          Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              'Cần kiểm tra: lượng, đơn vị hoặc lô chưa rõ',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.amber800,
              ),
            ),
          ),
      ],
    );
  }
}
