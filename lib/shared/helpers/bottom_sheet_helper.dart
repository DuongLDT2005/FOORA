import 'package:flutter/material.dart';

import '../components/app_bottom_sheet.dart';
import '../components/app_select_bottom_sheet.dart';

export '../components/app_select_bottom_sheet.dart' show SelectOption;

class BottomSheetHelper {
  BottomSheetHelper._();

  /// Shows the styled modal bottom sheet with [AppBottomSheet] container
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightFactor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) => AppBottomSheet(
        title: title,
        maxHeightFactor: maxHeightFactor,
        child: child,
      ),
    );
  }

  /// Shows a single-selection bottom sheet (List with checkmarks or Wrap chips)
  static Future<T?> showSelect<T>(
    BuildContext context, {
    required String title,
    required List<SelectOption<T>> options,
    required T selectedValue,
    ValueChanged<T>? onSelected,
    bool isGrid = false,
    String? description,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightFactor,
  }) {
    return show<T>(
      context,
      title: title,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      maxHeightFactor: maxHeightFactor,
      child: AppSelectBottomSheet<T>(
        options: options,
        selectedValue: selectedValue,
        isGrid: isGrid,
        description: description,
        onSelected: (val) {
          onSelected?.call(val);
        },
      ),
    );
  }
}
