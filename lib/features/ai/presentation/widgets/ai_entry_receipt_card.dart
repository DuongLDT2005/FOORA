import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../inventory/presentation/widgets/food_image_avatar.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/services/ai_food_category.dart';
import '../providers/ai_provider.dart';
import '../../../../shared/widgets/app_button.dart';

class AiEntryReceiptCard extends ConsumerStatefulWidget {
  const AiEntryReceiptCard({super.key, required this.message, this.onEdit});

  final AiChatMessage message;
  final VoidCallback? onEdit;

  @override
  ConsumerState<AiEntryReceiptCard> createState() => _AiEntryReceiptCardState();
}

class _AiEntryReceiptCardState extends ConsumerState<AiEntryReceiptCard> {
  final Map<String, String> _categories = {};
  List<Map<String, dynamic>>? _retryDecisions;
  bool _sending = false;
  String? _error;

  String? _categoryId(AiAction action) =>
      _categories[action.actionId] ??
      action.categoryId ??
      suggestAiCategoryId(action.name);

  /// The matched catalog food stays linked only while its category is kept;
  /// the server rejects a foodId whose category differs.
  String? _foodId(AiAction action) =>
      action.foodId != null && _categoryId(action) == action.categoryId
      ? action.foodId
      : null;

  String _amount(AiAction action) {
    final quantity = action.quantity;
    if (quantity == null) return '—';
    final number = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$number ${action.unit ?? ''}'.trim();
  }

  Future<void> _confirm() async {
    if (_sending || widget.message.actionStatus != 'proposed') return;
    final knownCategories = ref.read(foodCategoriesProvider).valueOrNull ?? [];
    final knownLocations = ref.read(storageLocationsProvider).valueOrNull ?? [];
    final decisions = <Map<String, dynamic>>[];
    for (final action in widget.message.actions) {
      final categoryId = _categoryId(action);
      final locationId = action.storageLocationId ?? 'fridge';
      if (action.quantity == null ||
          action.quantity! <= 0 ||
          action.name.trim().isEmpty ||
          action.unit?.trim().isEmpty != false ||
          categoryId == null ||
          !knownCategories.any((category) => category.id == categoryId) ||
          !knownLocations.any((location) => location.id == locationId)) {
        setState(
          () =>
              _error = 'Kiểm tra tên, lượng, danh mục hoặc mở phần sửa phiếu.',
        );
        return;
      }
      decisions.add({
        'actionId': action.actionId,
        'accept': true,
        'name': action.name,
        'quantity': action.quantity,
        'unit': action.unit,
        'categoryId': categoryId,
        'storageLocationId': locationId,
        'foodId': ?_foodId(action),
      });
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
      if (mounted) setState(() => _error = 'Không thể nhập kho. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(foodCategoriesProvider);
    final locationAsync = ref.watch(storageLocationsProvider);
    final categories = categoryAsync.valueOrNull ?? [];
    final locations = locationAsync.valueOrNull ?? [];
    final pending = widget.message.actionStatus == 'proposed';
    final canConfirm =
        categoryAsync.hasValue &&
        locationAsync.hasValue &&
        widget.message.actions.every((action) {
          final categoryId = _categoryId(action);
          return action.name.trim().isNotEmpty &&
              action.quantity != null &&
              action.quantity! > 0 &&
              action.unit?.trim().isNotEmpty == true &&
              categoryId != null &&
              categories.any((category) => category.id == categoryId) &&
              locations.any(
                (location) =>
                    location.id == (action.storageLocationId ?? 'fridge'),
              );
        });

    final locationIds = widget.message.actions
        .map((action) => action.storageLocationId ?? 'fridge')
        .toSet();
    final locationLabel = locationIds.length > 1
        ? 'Nhiều vị trí'
        : locationIds.single == 'freezer'
        ? 'Ngăn đông'
        : 'Ngăn mát';

    final hasEdit = pending && widget.onEdit != null;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      // The edit link carries its own padding below.
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, hasEdit ? 6.h : 16.h),
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
                  'Phiếu nhập tủ lạnh',
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
            if (index > 0)
              Divider(
                height: 21.h,
                indent: 40.r + 12.w,
                color: AppColors.slate100,
              ),
            _buildLine(widget.message.actions[index], categories, pending),
          ],
          SizedBox(height: 14.h),
          Text(
            pending
                ? 'Chưa nhập kho · Kiểm tra rồi xác nhận'
                : widget.message.actionStatus == 'applied'
                ? 'Đã nhập kho'
                : 'Phiếu không còn hiệu lực',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
          ),
          if (pending && categoryAsync.isLoading)
            Text(
              'Đang tải danh mục…',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
              ),
            ),
          if (pending && categoryAsync.hasError)
            TextButton(
              onPressed: () => ref.invalidate(foodCategoriesProvider),
              child: const AppButtonLabel('Không tải được danh mục · Thử lại'),
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
                child: AppButtonLabel(
                  _sending ? 'Đang nhập kho…' : 'Xác nhận nhập kho',
                ),
              ),
            ),
            if (hasEdit) ...[
              SizedBox(height: 4.h),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onEdit,
                  child: const AppButtonLabel('Sửa tên, lượng hoặc hạn dùng'),
                ),
              ),
            ],
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
    final categoryLabel = category?.name ?? 'Chọn danh mục';
    final linked = _foodId(action) != null;
    final details = [
      if (action.spokenName != null) 'Bạn nói: ${action.spokenName}',
      if (action.expirationDate != null && (!pending || linked))
        'HSD dự kiến ${aiDisplayDate(action.expirationDate!)}',
    ];
    final line = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: action.name,
                  children: [
                    if (linked)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(left: 6.w),
                          child: Tooltip(
                            message: 'Đã khớp danh mục thực phẩm chuẩn',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 15.r,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
        if (details.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              details.join(' · '),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.slate600,
              ),
            ),
          ),
        if (pending && categories.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: PopupMenuButton<String>(
              tooltip: 'Đổi danh mục ${action.name}',
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
              // A chip, so the picker reads as tappable without the
              // empty height a bare 40px target leaves under the line.
              child: Container(
                padding: EdgeInsets.fromLTRB(10.w, 5.h, 6.w, 5.h),
                decoration: BoxDecoration(
                  color: category == null ? AppColors.red50 : AppColors.slate50,
                  border: Border.all(
                    color: category == null
                        ? AppColors.red100
                        : AppColors.slate200,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: category == null
                            ? AppColors.red700
                            : AppColors.slate600,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18.r,
                      color: AppColors.slate600,
                    ),
                  ],
                ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodImageAvatar(
          photoUrl: action.photoUrl,
          categoryId: categoryId ?? '',
          size: 40,
          borderRadius: 12,
          backgroundColor: AppColors.slate50,
        ),
        SizedBox(width: 12.w),
        Expanded(child: line),
      ],
    );
  }
}

/// `2026-10-30` → `30/10/2026`; anything else is shown unchanged.
/// `2` instead of `2.0`, at most two decimals otherwise.
String aiDisplayNumber(double value) => value % 1 == 0
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String aiDisplayDate(String isoDay) {
  final parts = isoDay.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : isoDay;
}
