import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/nearby_store.dart';
import '../providers/nearby_stores_provider.dart';
import '../widgets/location_permission_view.dart';
import '../widgets/store_detail_card.dart';
import '../widgets/store_list_sheet.dart';
import '../widgets/store_marker.dart';

const _sheetMinSize = 0.28;
const _sheetInitialSize = 0.34;
const _sheetMaxSize = 0.74;

class NearbyStoresPage extends ConsumerStatefulWidget {
  const NearbyStoresPage({super.key});

  @override
  ConsumerState<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends ConsumerState<NearbyStoresPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Sheet height as a fraction of the page; overlays sit above it.
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_sheetInitialSize);

  LatLng? _mapCenter;

  /// Centre of the current store search; null means the user's location.
  LatLng? _searchCenter;
  bool _showSearchHere = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(
      () => ref.read(nearbyStoresControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Users come back from the location / app settings screens here.
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(nearbyStoresControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyStoresControllerProvider);
    final controller = ref.read(nearbyStoresControllerProvider.notifier);
    final location = state.userLocation;

    if (location == null) {
      final failure = state.locationFailure;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cửa hàng gần đây'),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _goBack,
          ),
        ),
        body: failure == null || state.isLocating
            ? const Center(child: CircularProgressIndicator())
            : LocationPermissionView(
                errorCode: failure.locationCode,
                onRetry: controller.load,
                onOpenSettings: () =>
                    controller.openSettings(failure.locationCode),
              ),
      );
    }

    final userPoint = LatLng(location.latitude, location.longitude);
    final stores = state.filteredStores;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: userPoint,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 19,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) _onMapMoved(position.center, userPoint);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrlTemplate,
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
                      onPressed: _goBack,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 11.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppColors.slate100),
                        ),
                        child: Text(
                          'Cửa hàng gần đây',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.slate800,
                          ),
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
            if (_showSearchHere)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 72.h,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () => _searchThisArea(controller),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(LucideIcons.search, size: 16.r),
                    label: const Text('Tìm lại khu vực này'),
                  ),
                ),
              ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                _sheetExtent.value = notification.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheetController,
                minChildSize: _sheetMinSize,
                initialChildSize: _sheetInitialSize,
                maxChildSize: _sheetMaxSize,
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
            ),
            // Overlays are painted after the sheet and follow its top edge,
            // so the OSM attribution and the directions card stay visible.
            ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, _) {
                final sheetTop = constraints.maxHeight * extent;
                return Stack(
                  children: [
                    Positioned(
                      right: 12.w,
                      bottom: sheetTop + 8.h,
                      child: TextButton(
                        onPressed: _openOsmCopyright,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: AppColors.slate700,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 4.h,
                          ),
                        ),
                        child: const Text('© OpenStreetMap contributors'),
                      ),
                    ),
                    if (state.selectedStore != null)
                      Positioned(
                        left: 16.w,
                        right: 16.w,
                        bottom: sheetTop + 44.h,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 440.w),
                            child: StoreDetailCard(
                              store: state.selectedStore!,
                              onClose: controller.clearSelection,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// OSM asks for `tile.openstreetmap.org`. Some Android emulator DNS setups
  /// resolve that host to localhost, so emulator runs use the `a` mirror.
  String get _tileUrlTemplate => AppConfig.instance.useFirebaseEmulator
      ? 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouteNames.home);
    }
  }

  void _onMapMoved(LatLng center, LatLng userPoint) {
    _mapCenter = center;
    const distance = Distance();
    final isFar =
        distance.as(LengthUnit.Meter, center, _searchCenter ?? userPoint) >
        1000;
    // Rebuild only when the button toggles, not on every drag frame.
    if (isFar != _showSearchHere) setState(() => _showSearchHere = isFar);
  }

  void _searchThisArea(NearbyStoresController controller) {
    final center = _mapCenter;
    if (center == null) return;
    setState(() {
      _searchCenter = center;
      _showSearchHere = false;
    });
    controller.searchThisArea(center.latitude, center.longitude);
  }

  void _focusStore(NearbyStoresController controller, NearbyStore store) {
    controller.selectStore(store);
    _mapController.move(LatLng(store.latitude, store.longitude), 17);
    // Leave room above the sheet for the directions card.
    if (_sheetController.isAttached &&
        _sheetController.size > _sheetInitialSize) {
      _sheetController.animateTo(
        _sheetMinSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
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
