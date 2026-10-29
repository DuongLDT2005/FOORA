import 'dart:math' as math;

import '../entities/nearby_store.dart';
import '../entities/user_location.dart';
import '../repositories/places_repository.dart';

class GetNearbyStores {
  const GetNearbyStores(this._repository);

  final PlacesRepository _repository;

  /// Returns up to 50 stores within [radiusMeters] of the search centre,
  /// nearest first. The centre is the user unless [searchLatitude] and
  /// [searchLongitude] are given ("search this area").
  Future<List<NearbyStore>> call({
    required UserLocation userLocation,
    double? searchLatitude,
    double? searchLongitude,
    int radiusMeters = 3000,
  }) async {
    final hasSearchCentre = searchLatitude != null && searchLongitude != null;
    final centreLatitude = hasSearchCentre
        ? searchLatitude
        : userLocation.latitude;
    final centreLongitude = hasSearchCentre
        ? searchLongitude
        : userLocation.longitude;

    final stores = await _repository.getNearbyStores(
      latitude: centreLatitude,
      longitude: centreLongitude,
      userLocation: userLocation,
      radiusMeters: radiusMeters,
    );

    // Store distances are measured from the user, so an area search needs
    // its own distance to the searched centre.
    double distanceFromCentre(NearbyStore store) => hasSearchCentre
        ? _distanceMeters(
            centreLatitude,
            centreLongitude,
            store.latitude,
            store.longitude,
          )
        : store.distanceMeters;

    final ranked =
        [
            for (final store in stores)
              (store: store, distance: distanceFromCentre(store)),
          ].where((entry) => entry.distance <= radiusMeters).toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));

    if (ranked.length < 5 && radiusMeters < 5000) {
      return call(
        userLocation: userLocation,
        searchLatitude: searchLatitude,
        searchLongitude: searchLongitude,
        radiusMeters: 5000,
      );
    }
    return ranked.take(50).map((entry) => entry.store).toList(growable: false);
  }
}

/// Haversine distance in metres.
double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  double toRadians(double degrees) => degrees * math.pi / 180;
  final dLat = toRadians(lat2 - lat1);
  final dLng = toRadians(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRadians(lat1)) *
          math.cos(toRadians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.sqrt(a));
}
