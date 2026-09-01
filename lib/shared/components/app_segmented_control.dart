import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SegmentedItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? badgeCount;

  const SegmentedItem({
    required this.value,
    required this.label,
    this.icon,
    this.badgeCount,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final T selectedValue;
  final List<SegmentedItem<T>> items;
  final ValueChanged<T> onValueChanged;
  final Color selectedColor;
  final Color unselectedTextColor;
  final Color backgroundColor;

  const AppSegmentedControl({
    super.key,
    required this.selectedValue,
    required this.items,
    required this.onValueChanged,
    this.selectedColor = AppColors.primary,
    this.unselectedTextColor = AppColors.slate600,
    this.backgroundColor = AppColors.slate100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item.value == selectedValue;

          return Expanded(
            child: GestureDetector(
              onTap: () => onValueChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected ? selectedColor : unselectedTextColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? selectedColor : unselectedTextColor,
                      ),
                    ),
                    if (item.badgeCount != null && item.badgeCount! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColor.withValues(alpha: 0.1)
                              : AppColors.slate200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? selectedColor
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
