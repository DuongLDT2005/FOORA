import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/location_datasource.dart';
import '../../data/datasources/places_remote_datasource.dart';
import '../../data/repositories/places_repository_impl.dart';
import '../../domain/entities/nearby_store.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/places_repository.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../domain/usecases/get_nearby_stores.dart';
import '../../domain/usecases/open_location_settings.dart';
import '../widgets/store_labels.dart';

final _placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final devLocation = AppEnv.devLocation;
  return PlacesRepositoryImpl(
    locationDataSource: LocationDataSourceImpl(
      fixedLocation: devLocation == null
          ? null
          : UserLocation(
              latitude: devLocation.latitude,
              longitude: devLocation.longitude,
              accuracy: 20,
            ),
    ),
    remoteDataSource: PlacesRemoteDataSourceImpl(ref.watch(functionsProvider)),
  );
});

@immutable
class NearbyStoresState {
  const NearbyStoresState({
    this.userLocation,
    this.stores = const [],
    this.isLocating = false,
    this.isLoadingStores = false,
    this.locationFailure,
    this.storesFailure,
    this.filter = StoreFilter.all,
    this.selectedStore,
  });

  final UserLocation? userLocation;
  final List<NearbyStore> stores;
  final bool isLocating;
  final bool isLoadingStores;
  final LocationFailure? locationFailure;
  final Failure? storesFailure;
  final StoreFilter filter;
  final NearbyStore? selectedStore;

  List<NearbyStore> get filteredStores => stores
      .where((store) => filter.includes(store.kind))
      .toList(growable: false);

  NearbyStoresState copyWith({
    UserLocation? userLocation,
    List<NearbyStore>? stores,
    bool? isLocating,
    bool? isLoadingStores,
    LocationFailure? locationFailure,
    Failure? storesFailure,
    StoreFilter? filter,
    NearbyStore? selectedStore,
    bool clearLocationFailure = false,
    bool clearStoresFailure = false,
    bool clearSelectedStore = false,
  }) {
    return NearbyStoresState(
      userLocation: userLocation ?? this.userLocation,
      stores: stores ?? this.stores,
      isLocating: isLocating ?? this.isLocating,
      isLoadingStores: isLoadingStores ?? this.isLoadingStores,
      locationFailure: clearLocationFailure
          ? null
          : locationFailure ?? this.locationFailure,
      storesFailure: clearStoresFailure
          ? null
          : storesFailure ?? this.storesFailure,
      filter: filter ?? this.filter,
      selectedStore: clearSelectedStore
          ? null
          : selectedStore ?? this.selectedStore,
    );
  }
}

final nearbyStoresControllerProvider =
    NotifierProvider.autoDispose<NearbyStoresController, NearbyStoresState>(
      NearbyStoresController.new,
    );

class NearbyStoresController extends AutoDisposeNotifier<NearbyStoresState> {
  GetCurrentLocation get _getCurrentLocation =>
      GetCurrentLocation(ref.read(_placesRepositoryProvider));
  GetNearbyStores get _getNearbyStores =>
      GetNearbyStores(ref.read(_placesRepositoryProvider));
  OpenLocationSettings get _openLocationSettings =>
      OpenLocationSettings(ref.read(_placesRepositoryProvider));

  @override
  NearbyStoresState build() => const NearbyStoresState();

  Future<void> load() async {
    // A second permission request while one is open throws on Android.
    if (state.isLocating) return;
    state = state.copyWith(
      isLocating: true,
      clearLocationFailure: true,
      clearStoresFailure: true,
    );
    try {
      final location = await _getCurrentLocation();
      state = state.copyWith(userLocation: location, isLocating: false);
    } on LocationFailure catch (error) {
      state = state.copyWith(isLocating: false, locationFailure: error);
      return;
    } catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationFailure: LocationFailure(
          LocationErrorCode.timeout,
          error is Failure ? error.message : null,
        ),
      );
      return;
    }
    await _loadStores(state.userLocation!);
  }

  /// Retries after the user returns from the system settings screen.
  Future<void> onAppResumed() async {
    if (state.userLocation == null && state.locationFailure != null) {
      await load();
    }
  }

  Future<void> openSettings(LocationErrorCode code) => _openLocationSettings(
    appSettings: code == LocationErrorCode.deniedForever,
  );

  Future<void> refreshStores() async {
    final location = state.userLocation;
    if (location != null) {
      await _loadStores(location);
    } else {
      await load();
    }
  }

  Future<void> searchThisArea(double latitude, double longitude) async {
    final location = state.userLocation;
    if (location == null) return;
    await _loadStores(
      location,
      searchLatitude: latitude,
      searchLongitude: longitude,
    );
  }

  Future<void> _loadStores(
    UserLocation location, {
    double? searchLatitude,
    double? searchLongitude,
  }) async {
    state = state.copyWith(
      isLoadingStores: true,
      clearStoresFailure: true,
      clearSelectedStore: true,
    );
    try {
      final stores = await _getNearbyStores(
        userLocation: location,
        searchLatitude: searchLatitude,
        searchLongitude: searchLongitude,
      );
      state = state.copyWith(isLoadingStores: false, stores: stores);
    } on Failure catch (error) {
      state = state.copyWith(isLoadingStores: false, storesFailure: error);
    } catch (_) {
      state = state.copyWith(
        isLoadingStores: false,
        storesFailure: const ServerFailure('Không thể tải cửa hàng gần đây.'),
      );
    }
  }

  void setFilter(StoreFilter filter) => state = state.copyWith(filter: filter);

  void selectStore(NearbyStore store) =>
      state = state.copyWith(selectedStore: store);

  void clearSelection() => state = state.copyWith(clearSelectedStore: true);
}
