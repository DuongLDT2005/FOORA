import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? localImagePath;
  final String initials;
  final double size;
  final bool showCameraBadge;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.localImagePath,
    required this.initials,
    this.size = 72,
    this.showCameraBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double avatarSize = size.r;

    Widget imageWidget;
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      imageWidget = Image.file(
        File(localImagePath!),
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: avatarSize,
            height: avatarSize,
            color: AppColors.emerald50,
            child: Center(
              child: SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = _buildFallback();
    }

    final avatarCircle = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.slate100, width: 5.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: imageWidget),
    );

    if (!showCameraBadge) {
      return GestureDetector(onTap: onTap, child: avatarCircle);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(LucideIcons.camera, size: 14.r, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.titleLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: (size * 0.38).sp,
        ),
      ),
    );
  }
}
