import '../entities/nearby_store.dart';
import '../entities/user_location.dart';

abstract class PlacesRepository {
  Future<UserLocation> getCurrentLocation();

  Future<List<NearbyStore>> getNearbyStores({
    required double latitude,
    required double longitude,
    required UserLocation userLocation,
    required int radiusMeters,
  });
}
