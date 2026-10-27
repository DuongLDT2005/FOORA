import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_shimmer.dart';
import '../../domain/entities/nearby_store.dart';

class StoreListSheet extends StatelessWidget {
  const StoreListSheet({
    super.key,
    required this.controller,
    required this.stores,
    required this.filter,
    required this.onFilterChanged,
    required this.onStoreTap,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
  });

  final ScrollController controller;
  final List<NearbyStore> stores;
  final StoreFilter filter;
  final ValueChanged<StoreFilter> onFilterChanged;
  final ValueChanged<NearbyStore> onStoreTap;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 28.h),
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Cửa hàng gần bạn',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.slate800,
              fontSize: 19.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Khoảng cách đường chim bay · Dữ liệu © OpenStreetMap',
            style: AppTextStyles.caption.copyWith(color: AppColors.slate500),
          ),
          SizedBox(height: 14.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: StoreFilter.values
                  .map(
                    (item) => Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: ChoiceChip(
                        label: Text(item.label),
                        selected: filter == item,
                        onSelected: (_) => onFilterChanged(item),
                        selectedColor: AppColors.primarySurface,
                        labelStyle: AppTextStyles.labelMedium.copyWith(
                          color: filter == item
                              ? AppColors.primary
                              : AppColors.slate600,
                        ),
                        side: BorderSide(
                          color: filter == item
                              ? AppColors.primary
                              : AppColors.slate200,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          SizedBox(height: 12.h),
          if (isLoading) const _StoreListLoading()
          else if (errorMessage != null) _StoreListError(message: errorMessage!, onRetry: onRetry)
          else if (stores.isEmpty) const _StoreListEmpty()
          else
            ...stores.map(
              (store) => _StoreRow(store: store, onTap: () => onStoreTap(store)),
            ),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store, required this.onTap});

  final NearbyStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        child: Row(
          children: [
            Icon(LucideIcons.store, color: AppColors.slate600, size: 18.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.slate800),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _metaText(store),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              _distanceLabel(store.distanceMeters),
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  String _metaText(NearbyStore store) => [
    store.kind.label,
    if (store.address != null) store.address!,
    if (store.openingHours != null) store.openingHours!,
  ].join(' · ');
}

class _StoreListLoading extends StatelessWidget {
  const _StoreListLoading();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
      (_) => Padding(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        child: AppShimmer(
          child: Container(height: 42.h, color: AppColors.slate100),
        ),
      ),
    ),
  );
}

class _StoreListEmpty extends StatelessWidget {
  const _StoreListEmpty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 28.h),
    child: Column(
      children: [
        Text(
          'Không tìm thấy cửa hàng trong 5 km.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate600),
        ),
        SizedBox(height: 8.h),
        const _OpenGoogleMapsButton(),
      ],
    ),
  );
}

class _StoreListError extends StatelessWidget {
  const _StoreListError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 20.h),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        const _OpenGoogleMapsButton(),
      ],
    ),
  );
}

class _OpenGoogleMapsButton extends StatelessWidget {
  const _OpenGoogleMapsButton();

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=siêu+thị'),
      mode: LaunchMode.externalApplication,
    ),
    icon: const Icon(LucideIcons.externalLink, size: 15),
    label: const Text('Tìm trên Google Maps'),
  );
}

String _distanceLabel(double distanceMeters) {
  if (distanceMeters < 1000) return '≈ ${distanceMeters.round()} m';
  return '≈ ${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
