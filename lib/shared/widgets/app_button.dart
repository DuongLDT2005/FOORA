import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- AppButtonLabel ---
/// Keeps button text on one line, shrinking it when the button is narrow
/// (e.g. 2-3 buttons side by side in a dialog) instead of wrapping.
class AppButtonLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AppButtonLabel(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}

/// Smaller side padding than the theme default, so labels fit in
/// buttons that share a row.
EdgeInsetsGeometry get _compactPadding =>
    EdgeInsets.symmetric(horizontal: 12.w, vertical: 16);

// --- PrimaryButton ---
/// Main call-to-action button with loading state.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(padding: _compactPadding),
        child: isLoading
            ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : AppButtonLabel(text),
      ),
    );
  }
}

// --- SecondaryButton ---
/// Outlined secondary button.
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const SecondaryButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(padding: _compactPadding),
        child: AppButtonLabel(text),
      ),
    );
  }
}

// --- DangerButton ---
/// Red button for destructive actions (delete, logout).
class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const DangerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: 20.r, color: AppColors.red500)
            : const SizedBox.shrink(),
        label: AppButtonLabel(
          text,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.red500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.red500.withValues(alpha: 0.05),
          side: BorderSide(color: AppColors.red500.withValues(alpha: 0.2)),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// --- AppFloatingActionButton ---
/// Floating action button in the app's style.
class AppFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppFloatingActionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 4.r),
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(Icons.add, size: 28.r),
      ),
    );
  }
}

// --- AppButton Unified Facade ---
/// Facade with static helpers to create the button variants above.
class AppButton {
  AppButton._();

  static Widget primary({
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    if (icon != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 18.r),
          label: AppButtonLabel(label),
        ),
      );
    }
    return PrimaryButton(
      text: label,
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  static Widget secondary({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    if (icon != null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18.r),
          label: AppButtonLabel(label),
        ),
      );
    }
    return SecondaryButton(text: label, onPressed: onPressed);
  }

  static Widget danger({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return DangerButton(text: label, onPressed: onPressed, icon: icon);
  }
}
