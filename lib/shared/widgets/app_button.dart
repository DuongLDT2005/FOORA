import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// --- PrimaryButton ---
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
        child: isLoading
            ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text),
      ),
    );
  }
}

// --- SecondaryButton ---
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const SecondaryButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(text)),
    );
  }
}

// --- DangerButton ---
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
        label: Text(
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
          padding: EdgeInsets.symmetric(vertical: 16.h),
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
          label: Text(label),
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
          label: Text(label),
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
