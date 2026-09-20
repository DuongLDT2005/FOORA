import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/food_category.dart';
import '../providers/inventory_provider.dart';

/// Reusable avatar widget for food items.
/// Business rule:
/// 1. If photoUrl is available, display the network image.
/// 2. If photoUrl is null or fails to load, display the Lucide icon of the item's category.
class FoodImageAvatar extends ConsumerWidget {
  final String? photoUrl;
  final String categoryId;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;

  const FoodImageAvatar({
    super.key,
    this.photoUrl,
    required this.categoryId,
    this.size = 40,
    this.borderRadius = 12,
    this.backgroundColor,
    this.iconColor,
  });

  static IconData getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'lucide-carrot':
        return LucideIcons.carrot;
      case 'lucide-apple':
        return LucideIcons.apple;
      case 'lucide-beef':
        return LucideIcons.beef;
      case 'lucide-fish':
        return LucideIcons.fish;
      case 'lucide-egg':
        return LucideIcons.egg;
      case 'lucide-wheat':
        return LucideIcons.wheat;
      case 'lucide-flask-conical':
        return LucideIcons.flaskConical;
      case 'lucide-cup-soda':
        return LucideIcons.cupSoda;
      case 'lucide-snowflake':
        return LucideIcons.snowflake;
      case 'lucide-package':
        return LucideIcons.package;
      default:
        return LucideIcons.utensils;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    FoodCategory? matchedCat;
    for (final cat in categories) {
      if (cat.id == categoryId) {
        matchedCat = cat;
        break;
      }
    }

    final iconData = getCategoryIcon(matchedCat?.icon ?? categoryId);
    final effectiveBg = backgroundColor ?? Colors.white;
    final effectiveIconColor = iconColor ?? AppColors.primary;

    Widget fallbackIconWidget() {
      return Center(
        child: Icon(
          iconData,
          color: effectiveIconColor,
          size: (size * 0.52).r,
        ),
      );
    }

    final hasValidPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius.r),
        border: Border.all(color: AppColors.slate100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius.r),
        child: hasValidPhoto
            ? Image.network(
                photoUrl!.trim(),
                width: size.r,
                height: size.r,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackIconWidget(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return fallbackIconWidget();
                },
              )
            : fallbackIconWidget(),
      ),
    );
  }
}
