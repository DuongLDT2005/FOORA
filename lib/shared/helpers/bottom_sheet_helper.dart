import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
    Widget? footer,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // The tab pages live in a nested StatefulShellRoute navigator; opening
      // the sheet there kept the bottom navigation bar above it and the scrim
      // only covered the tab body. The root navigator overlays everything.
      useRootNavigator: true,
      useSafeArea: true,
      barrierColor: AppColors.slate900.withValues(alpha: 0.55),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) => AppBottomSheet(
        title: title,
        maxHeightFactor: maxHeightFactor,
        footer: footer,
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
