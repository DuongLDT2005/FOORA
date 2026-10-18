import 'package:flutter/material.dart';

import '../components/app_dialog.dart';

class DialogHelper {
  DialogHelper._();

  /// Show standard confirmation dialog
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy',
    IconData icon = Icons.help_outline,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  /// Show destructive / delete confirmation dialog
  static Future<bool?> showDeleteDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xóa',
    String cancelText = 'Hủy',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: Icons.delete_outline,
        isDestructive: true,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  /// Show a dialog with cancel, a destructive [secondaryText] action and a
  /// primary [confirmText] action. Returns the value of the tapped action,
  /// or `null` when cancelled/dismissed.
  static Future<T?> showChoiceDialog<T>(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required T confirmValue,
    required String secondaryText,
    required T secondaryValue,
    String cancelText = 'Hủy',
    IconData icon = Icons.help_outline,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        secondaryText: secondaryText,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(confirmValue),
        onSecondary: () => Navigator.of(context).pop(secondaryValue),
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Show informational dialog (single OK button)
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Đã hiểu',
    IconData icon = Icons.info_outline,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        cancelText: null,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(),
      ),
    );
  }
}
