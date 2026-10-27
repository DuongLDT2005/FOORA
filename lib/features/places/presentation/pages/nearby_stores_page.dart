import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/nearby_store.dart';
import '../providers/nearby_stores_provider.dart';
import '../widgets/location_permission_view.dart';
import '../widgets/store_detail_card.dart';
import '../widgets/store_list_sheet.dart';
import '../widgets/store_marker.dart';

class NearbyStoresPage extends ConsumerStatefulWidget {
  const NearbyStoresPage({super.key});

  @override
  ConsumerState<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends ConsumerState<NearbyStoresPage> {
  final MapController _mapController = MapController();
  bool _hasLoaded = false;
  LatLng? _lastMapCenter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      Future<void>.microtask(
        () => ref.read(nearbyStoresControllerProvider.notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyStoresControllerProvider);
    final controller = ref.read(nearbyStoresControllerProvider.notifier);
    final location = state.userLocation;

    if (state.isLocating && location == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.locationFailure != null && location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cửa hàng gần đây')),
        body: LocationPermissionView(
          errorCode: state.locationFailure!.locationCode,
          onRetry: controller.load,
        ),
      );
    }
    if (location == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final userPoint = LatLng(location.latitude, location.longitude);
    final stores = state.filteredStores;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPoint,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _lastMapCenter = position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.foora.foora',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: userPoint,
                    radius: location.accuracy.clamp(8, 250).toDouble(),
                    useRadiusInMeter: true,
                    color: AppColors.blue500.withValues(alpha: 0.14),
                    borderColor: AppColors.blue500.withValues(alpha: 0.35),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: userPoint,
                    width: 28.r,
                    height: 28.r,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.blue500,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.r),
                      ),
                    ),
                  ),
                  ...stores.map(
                    (store) => Marker(
                      point: LatLng(store.latitude, store.longitude),
                      width: 46.r,
                      height: 46.r,
                      child: GestureDetector(
                        onTap: () => _focusStore(controller, store),
                        child: StoreMarker(
                          kind: store.kind,
                          isSelected: state.selectedStore?.id == store.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
              child: Row(
                children: [
                  _RoundMapButton(
                    icon: LucideIcons.arrowLeft,
                    tooltip: 'Quay lại',
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: AppColors.slate100),
                      ),
                      child: Text(
                        'Cửa hàng gần đây',
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.slate800),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  _RoundMapButton(
                    icon: LucideIcons.locateFixed,
                    tooltip: 'Vị trí của tôi',
                    onPressed: () => _mapController.move(userPoint, 15),
                  ),
                ],
              ),
            ),
          ),
          if (_shouldShowSearchHere(userPoint))
            Positioned(
              top: 82.h,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () {
                    final point = _lastMapCenter;
                    if (point != null) controller.searchThisArea(point.latitude, point.longitude);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(LucideIcons.search, size: 16),
                  label: const Text('Tìm lại khu vực này'),
                ),
              ),
            ),
          if (state.selectedStore != null)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 250.h,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 440.w),
                child: StoreDetailCard(
                  store: state.selectedStore!,
                  onClose: controller.clearSelection,
                ),
              ),
            ),
          Positioned(
            right: 12.w,
            bottom: 246.h,
            child: TextButton(
              onPressed: _openOsmCopyright,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: AppColors.slate700,
                minimumSize: Size.zero,
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
              ),
              child: const Text('© OpenStreetMap contributors'),
            ),
          ),
          DraggableScrollableSheet(
            minChildSize: 0.28,
            initialChildSize: 0.34,
            maxChildSize: 0.74,
            builder: (context, scrollController) => Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520.w),
                child: StoreListSheet(
                  controller: scrollController,
                  stores: stores,
                  filter: state.filter,
                  onFilterChanged: controller.setFilter,
                  onStoreTap: (store) => _focusStore(controller, store),
                  isLoading: state.isLoadingStores,
                  errorMessage: state.storesFailure?.message,
                  onRetry: controller.refreshStores,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _focusStore(NearbyStoresController controller, NearbyStore store) {
    controller.selectStore(store);
    _mapController.move(LatLng(store.latitude, store.longitude), 17);
  }

  bool _shouldShowSearchHere(LatLng userPoint) {
    final center = _lastMapCenter;
    if (center == null) return false;
    const distance = Distance();
    return distance.as(LengthUnit.Meter, center, userPoint) > 1000;
  }

  Future<void> _openOsmCopyright() => launchUrl(
    Uri.parse('https://www.openstreetmap.org/copyright'),
    mode: LaunchMode.externalApplication,
  );
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20.r, color: AppColors.slate700),
      ),
    ),
  );
}
