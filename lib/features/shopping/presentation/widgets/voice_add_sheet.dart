import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../shared/helpers/bottom_sheet_helper.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../inventory/presentation/widgets/unit_picker_field.dart';
import '../../domain/entities/shopping_item_draft.dart';
import '../../domain/usecases/parse_voice_shopping_text.dart';
import '../providers/shopping_providers.dart';
import 'shopping_item_tile.dart';

/// Unit used when neither the speaker nor the food catalogue gives one.
const String _fallbackVoiceUnit = 'quả';

/// Dictate several items at once ("2 hộp sữa, 1 kg thịt heo"). Recognised
/// text always becomes editable draft rows; nothing is saved until the user
/// confirms (PLAN_01 §2.1, §5.4).
class VoiceAddSheet extends ConsumerStatefulWidget {
  final String listId;

  const VoiceAddSheet({super.key, required this.listId});

  static Future<void> show(BuildContext context, {required String listId}) {
    return BottomSheetHelper.show<void>(
      context,
      title: 'Thêm bằng giọng nói',
      child: VoiceAddSheet(listId: listId),
    );
  }

  @override
  ConsumerState<VoiceAddSheet> createState() => _VoiceAddSheetState();
}

class _DraftRow {
  final TextEditingController name;
  final TextEditingController quantity;
  String unit;
  String? foodId;
  String? categoryId;

  _DraftRow({
    required String name,
    required double quantity,
    required this.unit,
  }) : name = TextEditingController(text: name),
       quantity = TextEditingController(text: formatShoppingQuantity(quantity));

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _VoiceAddSheetState extends ConsumerState<VoiceAddSheet> {
  late final VoiceInputService _voice;
  final List<_DraftRow> _rows = [];
  bool _isReady = false;
  bool _isUnavailable = false;
  bool _isListening = false;
  bool _isSaving = false;
  bool _missingVietnamese = false;
  String? _localeId;
  String _partialText = '';

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputServiceProvider);
    _prepare();
  }

  Future<void> _prepare() async {
    final available = await _voice.initialize();
    if (!mounted) return;
    if (!available) {
      setState(() => _isUnavailable = true);
      ToastHelper.show(
        context,
        'Thiết bị chưa hỗ trợ nhận dạng giọng nói, vui lòng nhập tay',
        isError: true,
      );
      return;
    }
    final localeId = await _voice.resolveVietnameseLocaleId();
    if (!mounted) return;
    setState(() {
      _localeId = localeId;
      _missingVietnamese = localeId == null;
      _isReady = true;
    });
  }

  @override
  void dispose() {
    _voice.cancel();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voice.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() {
      _isListening = true;
      _partialText = '';
    });
    await _voice.listen(
      localeId: _localeId,
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() => _partialText = text);
        if (isFinal) {
          setState(() => _isListening = false);
          _addRecognisedText(text);
        }
      },
    );
  }

  Future<void> _addRecognisedText(String text) async {
    final lines = ref.read(parseVoiceShoppingTextProvider)(text);
    for (final line in lines) {
      final row = _DraftRow(
        name: line.name,
        quantity: line.quantity,
        unit: line.unit ?? _fallbackVoiceUnit,
      );
      setState(() => _rows.add(row));
      await _fillFromCatalogue(row, keepUnit: line.unit != null);
    }
  }

  /// Uses the catalogue entry with the same name for its id, category and,
  /// when none was spoken, its default unit.
  Future<void> _fillFromCatalogue(
    _DraftRow row, {
    required bool keepUnit,
  }) async {
    try {
      final suggestions = await ref.read(
        shoppingFoodSuggestionsProvider(row.name.text).future,
      );
      final key = StringUtils.normalize(row.name.text);
      final match = suggestions
          .where((s) => StringUtils.normalize(s.name) == key)
          .firstOrNull;
      if (match == null || !mounted) return;
      setState(() {
        row.foodId = match.foodId;
        row.categoryId = match.categoryId;
        if (!keepUnit && match.defaultUnit.isNotEmpty) {
          row.unit = match.defaultUnit;
        }
      });
    } catch (_) {
      // Autocomplete is a convenience; the row stays editable without it.
    }
  }

  void _removeRow(_DraftRow row) {
    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _save() async {
    final drafts = <ShoppingItemDraft>[];
    for (final row in _rows) {
      final quantity = double.tryParse(
        row.quantity.text.trim().replaceAll(',', '.'),
      );
      if (row.name.text.trim().isEmpty || quantity == null || quantity <= 0) {
        ToastHelper.show(
          context,
          'Vui lòng kiểm tra tên và số lượng của từng món',
          isError: true,
        );
        return;
      }
      drafts.add(
        ShoppingItemDraft(
          name: row.name.text,
          quantity: quantity,
          unit: row.unit,
          foodId: row.foodId,
          categoryId: row.categoryId,
          source: ShoppingItemSource.voice,
        ),
      );
    }

    setState(() => _isSaving = true);
    final controller = ref.read(shoppingControllerProvider);
    try {
      for (final draft in drafts) {
        await controller.addItem(widget.listId, draft);
      }
      if (mounted) {
        ToastHelper.show(context, 'Đã thêm ${drafts.length} món vào danh sách');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, shoppingErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnavailable) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Text(
          'Thiết bị chưa hỗ trợ nhận dạng giọng nói. Vui lòng dùng "Nhập tay".',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate600),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_missingVietnamese)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.amber200),
                ),
                child: Text(
                  'Chưa có gói tiếng Việt. Cài đặt: Google app → Cài đặt → '
                  'Giọng nói → Ngôn ngữ.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.amber800,
                  ),
                ),
              ),
            Center(
              child: GestureDetector(
                onTap: _isReady && !_isSaving ? _toggleListening : null,
                child: Container(
                  width: 72.r,
                  height: 72.r,
                  decoration: BoxDecoration(
                    color: _isListening ? AppColors.red500 : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? LucideIcons.square : LucideIcons.mic,
                    color: AppColors.surfaceContainerLowest,
                    size: 30.r,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              _isListening
                  ? (_partialText.isEmpty ? 'Đang nghe...' : _partialText)
                  : 'Chạm để nói, ví dụ: "2 hộp sữa, 1 kg thịt heo và 6 quả trứng"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamilySans,
                fontSize: 13.sp,
                color: _isListening ? AppColors.slate800 : AppColors.slate500,
              ),
            ),
            if (_rows.isNotEmpty) ...[
              SizedBox(height: 16.h),
              for (final row in _rows) _buildRow(row),
              SizedBox(height: 16.h),
              PrimaryButton(
                text: 'Thêm vào danh sách (${_rows.length})',
                isLoading: _isSaving,
                onPressed: _isListening ? null : _save,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_DraftRow row) {
    final units = {...shoppingUnits, row.unit}.toList();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: const BorderSide(color: AppColors.slate200),
        ),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            children: [
              AppTextField(
                label: 'Tên món',
                isRequired: true,
                controller: row.name,
                fillColor: AppColors.surfaceContainerLowest,
                headerTrailing: InkWell(
                  onTap: () => _removeRow(row),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.all(2.r),
                    child: Icon(
                      LucideIcons.trash2,
                      size: 16.r,
                      color: AppColors.red500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Số lượng',
                      isRequired: true,
                      controller: row.quantity,
                      fillColor: AppColors.surfaceContainerLowest,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: UnitPickerField(
                      unit: row.unit,
                      units: units,
                      onChanged: (unit) => setState(() => row.unit = unit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
