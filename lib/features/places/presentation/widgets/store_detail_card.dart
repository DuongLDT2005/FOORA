import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/nearby_store.dart';

class StoreDetailCard extends StatelessWidget {
  const StoreDetailCard({super.key, required this.store, required this.onClose});

  final NearbyStore store;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.slate800,
                      fontSize: 17.sp,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(LucideIcons.x, size: 18.r),
                  color: AppColors.slate500,
                ),
              ],
            ),
            Text(
              '${_distanceLabel(store.distanceMeters)} · ${store.kind.label}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate600),
            ),
            if (store.address != null) ...[
              SizedBox(height: 6.h),
              Text(
                store.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
              ),
            ],
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: FilledButton.icon(
                onPressed: () => _openDirections(store),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(LucideIcons.navigation, size: 17.r),
                label: const Text('Chỉ đường'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openDirections(NearbyStore store) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${store.latitude},${store.longitude}',
      'travelmode': 'driving',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _distanceLabel(double distanceMeters) {
  if (distanceMeters < 1000) return '≈ ${distanceMeters.round()} m';
  return '≈ ${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
