import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../inventory/domain/entities/food_category.dart';
import '../../../inventory/domain/entities/storage_location.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/services/ai_food_category.dart';
import '../providers/ai_provider.dart';

class AiActionReviewSheet extends ConsumerStatefulWidget {
  const AiActionReviewSheet({super.key, required this.message});

  final AiChatMessage message;

  @override
  ConsumerState<AiActionReviewSheet> createState() =>
      _AiActionReviewSheetState();
}

class _ActionDraft {
  _ActionDraft(AiAction action)
    : selected =
          action.type == 'add_inventory' || action.reviewState == 'ready',
      name = TextEditingController(text: action.name),
      quantity = TextEditingController(
        text: action.quantity == null
            ? ''
            : action.quantity! % 1 == 0
            ? action.quantity!.toInt().toString()
            : action.quantity.toString(),
      ),
      unit = TextEditingController(text: action.unit ?? ''),
      expiration = TextEditingController(),
      allocationQuantities = {
        for (final candidate in action.candidateBatches)
          candidate.itemId: TextEditingController(),
      },
      categoryId = action.categoryId ?? suggestAiCategoryId(action.name),
      locationId =
          action.storageLocationId ??
          (action.type == 'add_inventory' ? 'fridge' : null),
      targetItemId = action.targetItemId;

  bool selected;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController expiration;
  final Map<String, TextEditingController> allocationQuantities;
  bool manualAllocation = false;
  String? categoryId;
  String? locationId;
  String? targetItemId;

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

  void _changed() {
    _retryPayload = null;
    if (mounted) setState(() => _error = null);
  }

  List<Map<String, dynamic>>? _decisions() {
    final decisions = <Map<String, dynamic>>[];
    for (final action in widget.message.actions) {
      final draft = _drafts[action.actionId]!;
      if (!draft.selected) {
        decisions.add({'actionId': action.actionId, 'accept': false});
        continue;
      }
      final quantity = double.tryParse(
        draft.quantity.text.trim().replaceAll(',', '.'),
      );
      if (quantity == null ||
          !quantity.isFinite ||
          quantity < 0 ||
          (action.type != 'set_quantity' && quantity == 0)) {
        setState(() => _error = 'Kiểm tra lại số lượng của ${action.name}.');
        return null;
      }
      final decision = <String, dynamic>{
        'actionId': action.actionId,
        'accept': true,
        'quantity': quantity,
      };
      if (action.type == 'add_inventory') {
        if (draft.name.text.trim().isEmpty ||
            draft.unit.text.trim().isEmpty ||
            draft.categoryId == null ||
            draft.locationId == null) {
          setState(
            () => _error =
                'Bổ sung tên, đơn vị, danh mục và vị trí của ${action.name}.',
          );
          return null;
        }
        decision.addAll({
          'name': draft.name.text.trim(),
          'unit': draft.unit.text.trim(),
          'categoryId': draft.categoryId,
          'storageLocationId': draft.locationId,
        });
        if (draft.expiration.text.trim().isNotEmpty) {
          decision['expirationDate'] = draft.expiration.text.trim();
        }
      } else {
        final manualAllocation =
            draft.manualAllocation && action.type != 'set_quantity';
        if (action.reviewState == 'needsReview' &&
            !manualAllocation &&
            (draft.targetItemId == null || draft.targetItemId!.isEmpty)) {
          setState(() => _error = 'Chọn batch cho ${action.name}.');
          return null;
        }
        if (action.type == 'set_quantity' &&
            (draft.targetItemId == null || draft.targetItemId!.isEmpty)) {
          setState(() => _error = 'Chọn batch cần đặt lượng còn lại.');
          return null;
        }
        if (manualAllocation) {
          final allocations = <Map<String, dynamic>>[];
          var allocated = 0.0;
          for (final candidate in action.candidateBatches) {
            final raw = draft.allocationQuantities[candidate.itemId]!.text
                .trim();
            if (raw.isEmpty) continue;
            final amount = double.tryParse(raw.replaceAll(',', '.'));
            if (amount == null ||
                !amount.isFinite ||
                amount <= 0 ||
                amount > candidate.quantity) {
              setState(() => _error = 'Kiểm tra lượng chia cho từng batch.');
              return null;
            }
            allocations.add({'itemId': candidate.itemId, 'quantity': amount});
            allocated += amount;
          }
          if (allocations.isEmpty || (allocated - quantity).abs() > 0.000001) {
            setState(() => _error = 'Tổng lượng các batch phải bằng số lượng.');
            return null;
          }
          decision['batchAllocations'] = allocations;
        } else if (draft.targetItemId != null &&
            draft.targetItemId!.isNotEmpty) {
          decision['targetItemId'] = draft.targetItemId;
        }
        if (draft.unit.text.trim().isNotEmpty) {
          decision['unit'] = draft.unit.text.trim();
        }
      }
      decisions.add(decision);
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
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(foodCategoriesProvider).valueOrNull ?? [];
    final locations = ref.watch(storageLocationsProvider).valueOrNull ?? [];
    final isEntryReceipt =
        widget.message.actions.isNotEmpty &&
        widget.message.actions.every(
          (action) => action.type == 'add_inventory',
        );
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardHeight;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: availableHeight * 0.88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isEntryReceipt
                              ? 'Sửa phiếu nhập'
                              : 'Duyệt cập nhật kho',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEntryReceipt
                              ? 'Kiểm tra thông tin trước khi thêm vào tủ.'
                              : 'Chỉ những mục được chọn mới làm thay đổi kho.',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < widget.message.actions.length;
                            index++
                          )
                            _buildAction(
                              widget.message.actions[index],
                              _drafts[widget.message.actions[index].actionId]!,
                              categories,
                              locations,
                              index: index,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                    child: Column(
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _sending ? null : _submit,
                            child: Text(
                              _sending
                                  ? 'Đang xác nhận…'
                                  : isEntryReceipt
                                  ? 'Xác nhận nhập kho'
                                  : 'Xác nhận quyết định',
                            ),
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
      ),
    );
  }

  Widget _buildAction(
    AiAction action,
    _ActionDraft draft,
    List<FoodCategory> categories,
    List<StorageLocation> locations, {
    required int index,
  }) {
    final isAdd = action.type == 'add_inventory';
    final chosenCategory = categories.any((item) => item.id == draft.categoryId)
        ? draft.categoryId
        : null;
    final chosenLocation = locations.any((item) => item.id == draft.locationId)
        ? draft.locationId
        : null;
    if (isAdd) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Món ${index + 1} · ${action.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Checkbox(
                    value: draft.selected,
                    onChanged: _sending
                        ? null
                        : (value) {
                            draft.selected = value ?? false;
                            _changed();
                          },
                  ),
                ],
              ),
              if (!draft.selected)
                const Text('Không thêm món này vào tủ')
              else ...[
                const SizedBox(height: 10),
                TextField(
                  controller: draft.name,
                  decoration: const InputDecoration(
                    labelText: 'Tên thực phẩm',
                    filled: false,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _changed(),
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
                        decoration: const InputDecoration(
                          labelText: 'Số lượng',
                          filled: false,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: draft.unit,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị',
                          filled: false,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: chosenCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    filled: false,
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    draft.categoryId = value;
                    _changed();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: chosenLocation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí bảo quản',
                    filled: false,
                    border: OutlineInputBorder(),
                  ),
                  items: locations
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    draft.locationId = value;
                    _changed();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: draft.expiration,
                  readOnly: true,
                  onTap: () => _pickExpiration(draft),
                  decoration: InputDecoration(
                    labelText: 'Hạn dùng (không bắt buộc)',
                    hintText: 'Chọn ngày',
                    filled: false,
                    border: const OutlineInputBorder(),
                    suffixIcon: draft.expiration.text.isEmpty
                        ? const Icon(Icons.calendar_today_outlined)
                        : IconButton(
                            tooltip: 'Bỏ hạn dùng',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              draft.expiration.clear();
                              _changed();
                            },
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final allowFefo =
        action.type != 'set_quantity' && action.reviewState == 'ready';
    final chosenBatch =
        action.candidateBatches.any((item) => item.itemId == draft.targetItemId)
        ? draft.targetItemId
        : (allowFefo ? '' : null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_label(action.type)}: ${action.name}'),
              subtitle: Text(
                isAdd
                    ? 'Kiểm tra tên, lượng, danh mục và hạn dùng'
                    : action.reviewState == 'needsReview'
                    ? 'Cần kiểm tra và bổ sung thông tin'
                    : 'Sẵn sàng để duyệt',
              ),
              value: draft.selected,
              onChanged: _sending
                  ? null
                  : (value) {
                      draft.selected = value ?? false;
                      _changed();
                    },
            ),
            if (draft.selected) ...[
              if (isAdd)
                TextField(
                  controller: draft.name,
                  decoration: const InputDecoration(labelText: 'Tên thực phẩm'),
                  onChanged: (_) => _changed(),
                ),
              TextField(
                controller: draft.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: action.type == 'set_quantity'
                      ? 'Lượng còn lại sau cập nhật'
                      : 'Số lượng',
                ),
                onChanged: (_) => _changed(),
              ),
              if (isAdd) ...[
                TextField(
                  controller: draft.unit,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                  onChanged: (_) => _changed(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: chosenCategory,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: categories
                      .map<DropdownMenuItem<String>>(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    draft.categoryId = value;
                    _changed();
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: chosenLocation,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí bảo quản',
                  ),
                  items: locations
                      .map<DropdownMenuItem<String>>(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    draft.locationId = value;
                    _changed();
                  },
                ),
                TextField(
                  controller: draft.expiration,
                  decoration: const InputDecoration(
                    labelText: 'Hạn dùng (YYYY-MM-DD, có thể để trống)',
                  ),
                  onChanged: (_) => _changed(),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextField(
                  controller: draft.unit,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                  onChanged: (_) => _changed(),
                ),
                if (action.type != 'set_quantity' &&
                    action.candidateBatches.length > 1)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chia số lượng theo batch'),
                    value: draft.manualAllocation,
                    onChanged: (value) {
                      draft.manualAllocation = value;
                      _changed();
                    },
                  ),
                if (draft.manualAllocation && action.type != 'set_quantity')
                  for (final candidate in action.candidateBatches)
                    TextField(
                      controller: draft.allocationQuantities[candidate.itemId],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            '${candidate.name} · còn ${candidate.quantity} ${candidate.unit}'
                            ' · HSD ${candidate.expirationDate ?? '?'}',
                      ),
                      onChanged: (_) => _changed(),
                    )
                else
                  DropdownButtonFormField<String>(
                    initialValue: chosenBatch,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: [
                      if (allowFefo)
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tự động FEFO'),
                        ),
                      ...action.candidateBatches.map(
                        (candidate) => DropdownMenuItem(
                          value: candidate.itemId,
                          child: Text(
                            '${candidate.name} · ${candidate.quantity} ${candidate.unit} '
                            '· HSD ${candidate.expirationDate ?? '?'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      draft.targetItemId = value;
                      _changed();
                    },
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _label(String type) => switch (type) {
    'consume' => 'Đã dùng',
    'discard' => 'Bỏ đi',
    'set_quantity' => 'Đặt lượng còn lại',
    'add_inventory' => 'Thêm vào kho',
    _ => type,
  };
}
