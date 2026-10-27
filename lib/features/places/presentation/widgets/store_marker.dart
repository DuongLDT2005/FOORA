import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nearby_store.dart';

class StoreMarker extends StatelessWidget {
  const StoreMarker({super.key, required this.kind, required this.isSelected});

  final StoreKind kind;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      StoreKind.supermarket => AppColors.primary,
      StoreKind.convenience => AppColors.blue500,
      StoreKind.greengrocer => AppColors.emerald600,
      StoreKind.butcher => AppColors.red500,
      StoreKind.marketplace => AppColors.amber600,
    };
    final icon = switch (kind) {
      StoreKind.supermarket => LucideIcons.store,
      StoreKind.convenience => LucideIcons.shoppingBasket,
      StoreKind.greengrocer => LucideIcons.carrot,
      StoreKind.butcher => LucideIcons.beef,
      StoreKind.marketplace => LucideIcons.tent,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: isSelected ? 44.r : 38.r,
      height: isSelected ? 44.r : 38.r,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: isSelected ? 3.r : 2.r),
      ),
      child: Icon(icon, color: color, size: 19.r),
    );
  }
}
