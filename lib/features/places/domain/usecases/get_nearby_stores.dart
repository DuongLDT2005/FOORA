import '../entities/nearby_store.dart';
import '../entities/user_location.dart';
import '../repositories/places_repository.dart';

class GetNearbyStores {
  const GetNearbyStores(this._repository);

  final PlacesRepository _repository;

  Future<List<NearbyStore>> call({
    required UserLocation userLocation,
    double? searchLatitude,
    double? searchLongitude,
    int radiusMeters = 3000,
  }) async {
    final stores = await _repository.getNearbyStores(
      latitude: searchLatitude ?? userLocation.latitude,
      longitude: searchLongitude ?? userLocation.longitude,
      userLocation: userLocation,
      radiusMeters: radiusMeters,
    );
    final withinRadius = stores
        .where((store) => store.distanceMeters <= radiusMeters)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (withinRadius.length < 5 && radiusMeters < 5000) {
      return call(
        userLocation: userLocation,
        searchLatitude: searchLatitude,
        searchLongitude: searchLongitude,
        radiusMeters: 5000,
      );
    }
    return withinRadius.take(50).toList(growable: false);
  }
}
