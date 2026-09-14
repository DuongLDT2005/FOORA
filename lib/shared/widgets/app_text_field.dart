import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// --- AppTextField ---
class AppTextField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final TextEditingController? controller;
  final bool isRequired;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final Color? fillColor;
  final Widget? headerTrailing;
  final double? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.controller,
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.fillColor,
    this.headerTrailing,
    this.borderRadius,
    this.contentPadding,
    this.textStyle,
    this.labelStyle,
    this.borderColor,
    this.focusedBorderColor,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.slate100;
    final effectiveFocusedBorderColor = focusedBorderColor ?? AppColors.primary;
    final effectiveRadius = borderRadius ?? 16.r;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: label.toUpperCase(),
                style:
                    labelStyle ??
                    AppTextStyles.inputLabel.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.slate400,
                    ),
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.red500),
                    ),
                ],
              ),
            ),
            ?headerTrailing,
          ],
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          enabled: enabled,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style:
              textStyle ??
              AppTextStyles.bodyMedium.copyWith(
                fontSize: 15.sp,
                color: AppColors.slate800,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              fontSize: 15.sp,
              color: AppColors.slate400,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: prefixIcon,
            prefixIconConstraints: BoxConstraints(
              minWidth: 48.w,
              minHeight: 48.h,
            ),
            suffixIcon: suffixIcon,
            suffixIconConstraints: BoxConstraints(
              minWidth: 48.w,
              minHeight: 48.h,
            ),
            filled: true,
            fillColor: fillColor ?? AppColors.slate50,
            contentPadding:
                contentPadding ??
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveRadius),
              borderSide: BorderSide(color: effectiveBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveRadius),
              borderSide: BorderSide(color: effectiveBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(effectiveRadius),
              borderSide: BorderSide(color: effectiveFocusedBorderColor),
            ),
          ),
        ),
      ],
    );
  }
}

// --- AppDropdown ---
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isRequired;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.slate600,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.red500),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.slate800,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.slate400,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.slate100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.slate100),
            ),
          ),
        ),
      ],
    );
  }
}

// --- AppPercentageSlider ---
class AppPercentageSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const AppPercentageSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: 'LƯỢNG CÒN LẠI',
                style: AppTextStyles.inputLabel.copyWith(
                  color: AppColors.slate600,
                ),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.red500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${value.toInt()}%',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.slate100,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
            trackHeight: 8,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hết',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
              Text(
                'Một nửa',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
              Text(
                'Đầy',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
