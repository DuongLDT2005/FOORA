import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/location_datasource.dart';
import '../../data/datasources/places_remote_datasource.dart';
import '../../data/repositories/places_repository_impl.dart';
import '../../domain/entities/nearby_store.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../domain/usecases/get_nearby_stores.dart';

final _placesRepositoryProvider = Provider<PlacesRepositoryImpl>((ref) {
  return PlacesRepositoryImpl(
    locationDataSource: const LocationDataSourceImpl(),
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

  List<NearbyStore> get filteredStores =>
      stores.where((store) => filter.includes(store.kind)).toList(growable: false);

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
      storesFailure: clearStoresFailure ? null : storesFailure ?? this.storesFailure,
      filter: filter ?? this.filter,
      selectedStore: clearSelectedStore
          ? null
          : selectedStore ?? this.selectedStore,
    );
  }
}

final nearbyStoresControllerProvider =
    NotifierProvider<NearbyStoresController, NearbyStoresState>(
      NearbyStoresController.new,
    );

class NearbyStoresController extends Notifier<NearbyStoresState> {
  late final GetCurrentLocation _getCurrentLocation;
  late final GetNearbyStores _getNearbyStores;

  @override
  NearbyStoresState build() {
    final repository = ref.watch(_placesRepositoryProvider);
    _getCurrentLocation = GetCurrentLocation(repository);
    _getNearbyStores = GetNearbyStores(repository);
    return const NearbyStoresState();
  }

  Future<void> load() async {
    state = state.copyWith(
      isLocating: true,
      clearLocationFailure: true,
      clearStoresFailure: true,
    );
    try {
      final location = await _getCurrentLocation();
      state = state.copyWith(userLocation: location, isLocating: false);
      await _loadStores(location);
    } on LocationFailure catch (error) {
      state = state.copyWith(isLocating: false, locationFailure: error);
    } on Failure catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationFailure: LocationFailure(
          LocationErrorCode.timeout,
          error.message,
        ),
      );
    }
  }

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
    }
  }

  void setFilter(StoreFilter filter) => state = state.copyWith(filter: filter);

  void selectStore(NearbyStore store) => state = state.copyWith(selectedStore: store);

  void clearSelection() => state = state.copyWith(clearSelectedStore: true);
}
