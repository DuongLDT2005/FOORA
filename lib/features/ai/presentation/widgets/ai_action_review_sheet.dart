import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/app_bottom_bar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../../inventory/domain/entities/storage_location.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/services/ai_food_category.dart';
import '../providers/ai_provider.dart';
import 'ai_entry_receipt_card.dart' show aiDisplayDate, aiDisplayNumber;

/// Edits and confirms the actions the assistant proposed. Nothing changes
/// inventory until the user confirms here or on the inline receipt.
class AiActionReviewSheet extends ConsumerStatefulWidget {
  const AiActionReviewSheet({super.key, required this.message});

  final AiChatMessage message;

  @override
  ConsumerState<AiActionReviewSheet> createState() =>
      _AiActionReviewSheetState();
}

/// Batches by expiry, nearest first, like the server's FEFO split.
List<AiActionCandidate> _byExpiry(List<AiActionCandidate> batches) =>
    [...batches]..sort(
      (a, b) =>
          (a.expirationDate ?? '9999').compareTo(b.expirationDate ?? '9999'),
    );

class _ActionDraft {
  _ActionDraft(AiAction action)
    // Every proposal starts selected: the user opened the sheet to apply it,
    // and an incomplete one cannot be confirmed until it is fixed.
    : selected = true,
      batches = _byExpiry(action.candidateBatches),
      name = TextEditingController(text: action.name),
      quantity = TextEditingController(),
      unit = TextEditingController(text: action.unit ?? ''),
      expiration = TextEditingController(),
      allocationQuantities = {
        for (final candidate in action.candidateBatches)
          candidate.itemId: TextEditingController(),
      },
      originalName = action.name,
      originalCategoryId = action.categoryId,
      originalLocationId = action.storageLocationId,
      foodId = action.foodId,
      estimatedExpiration = action.expirationDate,
      categoryId = action.categoryId ?? suggestAiCategoryId(action.name),
      locationId =
          action.storageLocationId ??
          (action.type == 'add_inventory' ? 'fridge' : null),
      targetItemId = action.targetItemId {
    // A spoken unit that differs from the stored one ("lạng" for a batch in
    // kg) is never converted: the amount is left for the user to re-enter.
    final keepAmount =
        action.quantity != null &&
        (stockUnit == null || action.unit == null || action.unit == stockUnit);
    if (keepAmount) quantity.text = aiDisplayNumber(action.quantity!);
    if (targetItemId == null &&
        batches.length == 1 &&
        (action.type == 'set_quantity' || action.reviewState != 'ready')) {
      targetItemId = batches.single.itemId;
    }
  }

  bool selected;
  final List<AiActionCandidate> batches;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController expiration;
  final String originalName;
  final String? originalCategoryId;
  final String? originalLocationId;
  final String? foodId;
  final String? estimatedExpiration;
  final Map<String, TextEditingController> allocationQuantities;
  bool manualAllocation = false;
  String? categoryId;
  String? locationId;

  /// Null means "automatic": nearest expiry first.
  String? targetItemId;
  String? error;

  /// Every candidate batch shares the unit of the inventory item.
  String? get stockUnit => batches.isEmpty ? null : batches.first.unit;

  double get stockTotal =>
      batches.fold(0, (total, batch) => total + batch.quantity);

  double? get amount {
    final value = double.tryParse(quantity.text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  /// Like the item form: renaming the food or changing its category unlinks
  /// the matched catalog food (and its photo and shelf-life rule).
  String? get linkedFoodId =>
      foodId != null &&
          name.text.trim() == originalName.trim() &&
          categoryId == originalCategoryId
      ? foodId
      : null;

  /// Shown under the empty expiry field: the server then calculates the
  /// date itself from the same shelf-life rules.
  String get expirationHelper {
    final linked = linkedFoodId != null;
    final estimate = estimatedExpiration;
    final source = linked ? 'hạn chuẩn' : 'danh mục';
    if (estimate != null &&
        categoryId == originalCategoryId &&
        locationId == originalLocationId &&
        (linked || foodId == null)) {
      return 'Để trống: tự tính theo $source (${aiDisplayDate(estimate)})';
    }
    return 'Để trống: tự tính theo $source';
  }

  /// Nearest-expiry split of [total], or null when stock is short.
  List<({AiActionCandidate batch, double quantity})>? fefo(double total) {
    var remaining = total;
    final result = <({AiActionCandidate batch, double quantity})>[];
    for (final batch in batches) {
      if (remaining <= 0) break;
      final take = remaining < batch.quantity ? remaining : batch.quantity;
      if (take > 0) result.add((batch: batch, quantity: take));
      remaining = double.parse((remaining - take).toStringAsFixed(6));
    }
    return remaining <= 0 ? result : null;
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    expiration.dispose();
    for (final controller in allocationQuantities.values) {
      controller.dispose();
    }
  }
}

class _AiActionReviewSheetState extends ConsumerState<AiActionReviewSheet> {
  late final Map<String, _ActionDraft> _drafts;
  List<Map<String, dynamic>>? _retryPayload;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = {
      for (final action in widget.message.actions)
        action.actionId: _ActionDraft(action),
    };
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  void _changed([_ActionDraft? draft]) {
    _retryPayload = null;
    draft?.error = null;
    if (mounted) setState(() => _error = null);
  }

  /// Checks one draft and returns its decision, or sets `draft.error`.
  Map<String, dynamic>? _decision(AiAction action, _ActionDraft draft) {
    if (!draft.selected) return {'actionId': action.actionId, 'accept': false};
    final quantity = draft.amount;
    final isSet = action.type == 'set_quantity';
    if (quantity == null || quantity < 0 || (!isSet && quantity == 0)) {
      draft.error = isSet ? 'Nhập lượng còn lại.' : 'Nhập số lượng lớn hơn 0.';
      return null;
    }
    final decision = <String, dynamic>{
      'actionId': action.actionId,
      'accept': true,
      'quantity': quantity,
    };
    if (action.type == 'add_inventory') {
      if (draft.name.text.trim().isEmpty) {
        draft.error = 'Nhập tên thực phẩm.';
      } else if (draft.unit.text.trim().isEmpty) {
        draft.error = 'Nhập đơn vị.';
      } else if (draft.categoryId == null || draft.locationId == null) {
        draft.error = 'Chọn danh mục và vị trí bảo quản.';
      }
      if (draft.error != null) return null;
      decision.addAll({
        'name': draft.name.text.trim(),
        'unit': draft.unit.text.trim(),
        'categoryId': draft.categoryId,
        'storageLocationId': draft.locationId,
        'foodId': ?draft.linkedFoodId,
      });
      if (draft.expiration.text.trim().isNotEmpty) {
        decision['expirationDate'] = draft.expiration.text.trim();
      }
      return decision;
    }

    if (draft.batches.isEmpty) {
      draft.error = 'Không tìm thấy lô nào trong tủ. Hãy hỏi lại AI.';
      return null;
    }
    decision['unit'] = draft.stockUnit;
    final unit = draft.stockUnit ?? '';
    if (isSet) {
      final batch = draft.batches
          .where((item) => item.itemId == draft.targetItemId)
          .firstOrNull;
      if (batch == null) {
        draft.error = 'Chọn lô cần đặt lại lượng.';
        return null;
      }
      if (quantity > batch.quantity) {
        draft.error =
            'Chỉ có thể giảm: lô này còn '
            '${aiDisplayNumber(batch.quantity)} $unit.';
        return null;
      }
      decision['targetItemId'] = batch.itemId;
      return decision;
    }
    if (quantity > draft.stockTotal + 0.000001) {
      draft.error =
          'Vượt quá lượng trong tủ '
          '(${aiDisplayNumber(draft.stockTotal)} $unit).';
      return null;
    }
    if (draft.manualAllocation) {
      final allocations = <Map<String, dynamic>>[];
      var allocated = 0.0;
      for (final batch in draft.batches) {
        final raw = draft.allocationQuantities[batch.itemId]!.text.trim();
        if (raw.isEmpty) continue;
        final value = double.tryParse(raw.replaceAll(',', '.'));
        if (value == null ||
            !value.isFinite ||
            value <= 0 ||
            value > batch.quantity) {
          draft.error = 'Lượng của mỗi lô phải từ 0 đến lượng còn của lô.';
          return null;
        }
        allocations.add({'itemId': batch.itemId, 'quantity': value});
        allocated += value;
      }
      if (allocations.isEmpty || (allocated - quantity).abs() > 0.000001) {
        draft.error =
            'Tổng các lô (${aiDisplayNumber(allocated)} $unit) phải bằng '
            '${aiDisplayNumber(quantity)} $unit.';
        return null;
      }
      decision['batchAllocations'] = allocations;
      return decision;
    }
    final target = draft.targetItemId;
    if (target != null) {
      final batch = draft.batches.firstWhere((item) => item.itemId == target);
      if (quantity > batch.quantity) {
        draft.error =
            'Lô này chỉ còn ${aiDisplayNumber(batch.quantity)} $unit. '
            'Chọn tự động để trừ qua nhiều lô.';
        return null;
      }
      decision['targetItemId'] = target;
    } else if (action.reviewState != 'ready') {
      // The server splits by FEFO only for ready proposals; a reviewed one
      // carries the split the user saw in the sheet.
      final parts = draft.fefo(quantity);
      if (parts == null) {
        draft.error = 'Không đủ lượng trong các lô.';
        return null;
      }
      decision['batchAllocations'] = [
        for (final part in parts)
          {'itemId': part.batch.itemId, 'quantity': part.quantity},
      ];
    }
    return decision;
  }

  List<Map<String, dynamic>>? _decisions() {
    final decisions = <Map<String, dynamic>>[];
    var invalid = 0;
    for (final action in widget.message.actions) {
      final draft = _drafts[action.actionId]!..error = null;
      final decision = _decision(action, draft);
      if (decision == null) {
        invalid++;
      } else {
        decisions.add(decision);
      }
    }
    if (invalid > 0) {
      setState(
        () => _error = invalid == 1
            ? 'Còn 1 mục cần sửa.'
            : 'Còn $invalid mục cần sửa.',
      );
      return null;
    }
    return decisions;
  }

  Future<void> _submit() async {
    if (_sending) return;
    final decisions = _retryPayload ?? _decisions();
    if (decisions == null) return;
    _retryPayload = decisions;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(applyAiActionsProvider)(
        messageId: widget.message.id,
        decisions: decisions,
      );
      if (mounted) Navigator.of(context).pop();
    } on Failure catch (error) {
      if (mounted) {
        if (error.code == 'failed-precondition') {
          ref.invalidate(activeHouseholdInventoryStreamProvider);
          setState(
            () => _error =
                'Kho hoặc đề xuất đã thay đổi. Hãy tải lại kho và hỏi AI lần nữa.',
          );
        } else {
          setState(() => _error = error.message);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể xác nhận. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickExpiration(_ActionDraft draft) async {
    final current = DateTime.tryParse(draft.expiration.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn hạn dùng',
    );
    if (picked == null) return;
    draft.expiration.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    _changed(draft);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(foodCategoriesProvider).valueOrNull ?? [];
    final locations = ref.watch(storageLocationsProvider).valueOrNull ?? [];
    final actions = widget.message.actions;
    final isEntryReceipt =
        actions.isNotEmpty &&
        actions.every((action) => action.type == 'add_inventory');
    final selectedCount = _drafts.values.where((item) => item.selected).length;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardHeight;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        // heightFactor 1: a scroll-controlled sheet may be as tall as the
        // screen, and a plain Center would float the content in the middle
        // with empty space above and below.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: availableHeight * 0.88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.slate200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isEntryReceipt
                              ? 'Sửa phiếu nhập'
                              : 'Kiểm tra cập nhật kho',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.slate800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEntryReceipt
                              ? 'Kiểm tra thông tin trước khi thêm vào tủ.'
                              : 'Sửa lượng hoặc chọn lô nếu cần. Bỏ chọn '
                                    'mục nào thì kho giữ nguyên mục đó.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.slate100),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: actions.length,
                      itemBuilder: (context, index) => _buildAction(
                        actions[index],
                        _drafts[actions[index].actionId]!,
                        categories,
                        locations,
                        index: index,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppColors.red700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.red700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Same Cancel/Save bar as the inventory item form.
                  AppBottomBar.form(
                    onCancel: () => Navigator.of(context).pop(),
                    onSubmit: _submit,
                    isSubmitting: _sending,
                    cancelLabel: 'Để sau',
                    submitLabel: selectedCount == 0
                        ? 'Bỏ qua phiếu này'
                        : isEntryReceipt
                        ? 'Xác nhận nhập kho'
                        : 'Cập nhật kho ($selectedCount)',
                    submitIcon: selectedCount == 0
                        ? Icons.block_rounded
                        : Icons.save_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(
    String label, {
    String? hint,
    String? helper,
    String? suffix,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: AppColors.slate600),
    suffixText: suffix,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: false,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _buildAction(
    AiAction action,
    _ActionDraft draft,
    List<FoodCategory> categories,
    List<StorageLocation> locations, {
    required int index,
  }) {
    final (icon, color, label) = switch (action.type) {
      'add_inventory' => (
        Icons.add_box_outlined,
        AppColors.primary,
        'Món ${index + 1} · Thêm vào tủ',
      ),
      'discard' => (Icons.delete_outline_rounded, AppColors.red700, 'Bỏ đi'),
      'set_quantity' => (
        Icons.tune_rounded,
        AppColors.slate600,
        'Đặt lại lượng còn',
      ),
      _ => (Icons.restaurant_rounded, AppColors.primary, 'Đã dùng'),
    };
    final isAdd = action.type == 'add_inventory';
    final unit = draft.stockUnit ?? '';
    final stock = isAdd || draft.batches.isEmpty
        ? null
        : 'Trong tủ ${aiDisplayNumber(draft.stockTotal)} $unit'
              '${draft.batches.length > 1 ? ' · ${draft.batches.length} lô' : ''}';
    final borderColor = draft.error != null
        ? AppColors.red500
        : draft.selected && !isAdd && action.reviewState != 'ready'
        ? AppColors.amber300
        : AppColors.slate200;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: draft.selected ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _sending
                  ? null
                  : () {
                      draft.selected = !draft.selected;
                      _changed(draft);
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  action.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ),
                              if (isAdd && draft.linkedFoodId != null)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Tooltip(
                                    message: 'Đã khớp danh mục thực phẩm chuẩn',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [label, ?stock].join(' · '),
                            style: TextStyle(fontSize: 13, color: color),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: draft.selected,
                      onChanged: _sending
                          ? null
                          : (value) {
                              draft.selected = value ?? false;
                              _changed(draft);
                            },
                    ),
                  ],
                ),
              ),
            ),
            if (!draft.selected)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  isAdd
                      ? 'Không thêm món này vào tủ'
                      : 'Bỏ qua, kho giữ nguyên',
                  style: const TextStyle(color: AppColors.slate600),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAdd)
                      ..._addFields(draft, categories, locations)
                    else
                      ..._inventoryFields(action, draft),
                    if (draft.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        draft.error!,
                        style: const TextStyle(
                          color: AppColors.red700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _addFields(
    _ActionDraft draft,
    List<FoodCategory> categories,
    List<StorageLocation> locations,
  ) {
    final chosenCategory = categories.any((item) => item.id == draft.categoryId)
        ? draft.categoryId
        : null;
    final chosenLocation = locations.any((item) => item.id == draft.locationId)
        ? draft.locationId
        : null;
    // Dropdowns default to titleMedium; the text fields beside them use
    // bodyLarge.
    final fieldStyle = Theme.of(context).textTheme.bodyLarge;
    return [
      TextField(
        controller: draft.name,
        decoration: _input('Tên thực phẩm'),
        onChanged: (_) => _changed(draft),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: draft.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _input('Số lượng'),
              onChanged: (_) => _changed(draft),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: draft.unit,
              decoration: _input('Đơn vị', hint: 'kg, quả, hộp…'),
              onChanged: (_) => _changed(draft),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: chosenCategory,
        isExpanded: true,
        style: fieldStyle,
        decoration: _input('Danh mục'),
        items: categories
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          draft.categoryId = value;
          _changed(draft);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: chosenLocation,
        isExpanded: true,
        style: fieldStyle,
        decoration: _input('Vị trí bảo quản'),
        items: locations
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          draft.locationId = value;
          _changed(draft);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: draft.expiration,
        readOnly: true,
        onTap: () => _pickExpiration(draft),
        decoration: _input(
          'Hạn dùng (không bắt buộc)',
          hint: 'Chọn ngày',
          helper: draft.expiration.text.isEmpty ? draft.expirationHelper : null,
          suffixIcon: draft.expiration.text.isEmpty
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Bỏ hạn dùng',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    draft.expiration.clear();
                    _changed(draft);
                  },
                ),
        ),
      ),
    ];
  }

  /// Why the assistant could not prepare this action on its own.
  String? _reviewReason(AiAction action, _ActionDraft draft) {
    if (action.reviewState == 'ready') return null;
    final unit = draft.stockUnit;
    if (draft.batches.isEmpty) return 'Không tìm thấy lô nào khớp trong tủ.';
    if (action.unit != null && unit != null && action.unit != unit) {
      return 'Bạn nói "${action.unit}" nhưng món này lưu theo "$unit". '
          'Hãy nhập lại lượng theo $unit.';
    }
    if (action.quantity == null) {
      return 'AI chưa rõ lượng. Hãy nhập lượng bạn đã '
          '${action.type == 'discard' ? 'bỏ' : 'dùng'}.';
    }
    if (action.type == 'set_quantity' && draft.batches.length > 1) {
      return 'Có nhiều lô, hãy chọn lô cần đặt lại lượng.';
    }
    if (action.quantity! > draft.stockTotal) {
      return 'Lượng AI ghi nhận nhiều hơn lượng trong tủ.';
    }
    return 'Hãy kiểm tra lượng và lô trước khi cập nhật.';
  }

  List<Widget> _inventoryFields(AiAction action, _ActionDraft draft) {
    final unit = draft.stockUnit ?? '';
    final isSet = action.type == 'set_quantity';
    final reason = _reviewReason(action, draft);
    final amount = draft.amount;
    final verb = action.type == 'discard' ? 'bỏ' : 'trừ';
    String? preview;
    var previewWarning = false;
    if (amount != null && amount >= 0 && draft.batches.isNotEmpty) {
      if (isSet) {
        final batch = draft.batches
            .where((item) => item.itemId == draft.targetItemId)
            .firstOrNull;
        if (batch != null) {
          previewWarning = amount > batch.quantity;
          preview =
              'Lô này: ${aiDisplayNumber(batch.quantity)} → '
              '${aiDisplayNumber(amount)} $unit';
        }
      } else {
        final left = draft.stockTotal - amount;
        previewWarning = left < -0.000001;
        preview = previewWarning
            ? 'Vượt quá ${aiDisplayNumber(-left)} $unit so với trong tủ'
            : 'Sau khi $verb còn ${aiDisplayNumber(left)} $unit';
      }
    }
    final step = draft.stockTotal > 0 && draft.stockTotal < 3 && unit != 'quả'
        ? 0.1
        : 1.0;
    return [
      if (reason != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.amber800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: const TextStyle(color: AppColors.amber800),
                ),
              ),
            ],
          ),
        ),
      Row(
        children: [
          _stepButton(Icons.remove_rounded, () {
            final next = ((draft.amount ?? 0) - step).clamp(0, double.infinity);
            draft.quantity.text = aiDisplayNumber(next.toDouble());
            _changed(draft);
          }),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: draft.quantity,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _input(
                isSet ? 'Lượng còn lại' : 'Lượng đã $verb',
                suffix: unit,
              ),
              onChanged: (_) => _changed(draft),
            ),
          ),
          const SizedBox(width: 8),
          _stepButton(Icons.add_rounded, () {
            draft.quantity.text = aiDisplayNumber((draft.amount ?? 0) + step);
            _changed(draft);
          }),
        ],
      ),
      if (preview != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            preview,
            style: TextStyle(
              fontSize: 13,
              color: previewWarning ? AppColors.red700 : AppColors.slate600,
            ),
          ),
        ),
      if (draft.batches.length > 1 || isSet) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                isSet ? 'Lô cần đặt lại' : 'Trừ từ lô nào?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate800,
                ),
              ),
            ),
            if (!isSet && draft.batches.length > 1)
              TextButton(
                onPressed: () {
                  draft.manualAllocation = !draft.manualAllocation;
                  _changed(draft);
                },
                child: AppButtonLabel(
                  draft.manualAllocation ? 'Chọn một lô' : 'Chia thủ công',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (draft.manualAllocation && !isSet)
          ..._manualAllocation(draft, amount)
        else ...[
          if (!isSet)
            _batchOption(
              selected: draft.targetItemId == null,
              title: 'Tự động: lô gần hết hạn trước',
              subtitle: _fefoSummary(draft, amount),
              onTap: () {
                draft.targetItemId = null;
                _changed(draft);
              },
            ),
          for (final batch in draft.batches)
            _batchOption(
              selected: draft.targetItemId == batch.itemId,
              title: _batchTitle(batch),
              subtitle: 'Còn ${aiDisplayNumber(batch.quantity)} ${batch.unit}',
              onTap: () {
                draft.targetItemId = batch.itemId;
                _changed(draft);
              },
            ),
        ],
      ] else if (draft.batches.length == 1)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            '${_batchTitle(draft.batches.single)} · còn '
            '${aiDisplayNumber(draft.batches.single.quantity)} $unit',
            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
          ),
        ),
    ];
  }

  String _batchTitle(AiActionCandidate batch) => batch.expirationDate == null
      ? 'Lô không có hạn dùng'
      : 'Lô HSD ${aiDisplayDate(batch.expirationDate!)}';

  String? _fefoSummary(_ActionDraft draft, double? amount) {
    if (amount == null || amount <= 0) return null;
    final parts = draft.fefo(amount);
    if (parts == null) return null;
    return parts
        .map(
          (part) =>
              '${aiDisplayNumber(part.quantity)} ${part.batch.unit} từ '
              '${part.batch.expirationDate == null ? 'lô không hạn' : aiDisplayDate(part.batch.expirationDate!)}',
        )
        .join(', ');
  }

  List<Widget> _manualAllocation(_ActionDraft draft, double? amount) {
    final unit = draft.stockUnit ?? '';
    var allocated = 0.0;
    for (final controller in draft.allocationQuantities.values) {
      allocated +=
          double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    }
    final matches = amount != null && (allocated - amount).abs() < 0.000001;
    return [
      for (final batch in draft.batches)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_batchTitle(batch)),
                    Text(
                      'Còn ${aiDisplayNumber(batch.quantity)} ${batch.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: draft.allocationQuantities[batch.itemId],
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _input('', hint: '0', suffix: batch.unit),
                  onChanged: (_) => _changed(draft),
                ),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Đã chia ${aiDisplayNumber(allocated)}'
          '${amount == null ? '' : '/${aiDisplayNumber(amount)}'} $unit',
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: matches ? AppColors.primary : AppColors.amber800,
          ),
        ),
      ),
    ];
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed) =>
      IconButton.outlined(
        onPressed: _sending ? null : onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          side: const BorderSide(color: AppColors.slate200),
          minimumSize: const Size(44, 44),
        ),
      );

  Widget _batchOption({
    required bool selected,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selected ? AppColors.emerald50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _sending ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.slate200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.slate400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
