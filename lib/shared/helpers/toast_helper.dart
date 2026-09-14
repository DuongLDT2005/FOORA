import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// --- ToastHelper ---
class ToastHelper {
  ToastHelper._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenHeight = mediaQuery.size.height;
    // Position toast neatly below status bar / notch
    final topMargin = topPadding > 0 ? topPadding + 8 : 24.0;
    // Standard snackbar height with padding ~60
    final bottomMargin = screenHeight - topMargin - 64;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: bottomMargin > 0 ? bottomMargin : 0,
            left: 16,
            right: 16,
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isError ? AppColors.red500 : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError ? Icons.error_outline : Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
