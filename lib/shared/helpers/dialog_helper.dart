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
