import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/nearby_store.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/places_repository.dart';
import '../datasources/location_datasource.dart';
import '../datasources/places_remote_datasource.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  const PlacesRepositoryImpl({
    required this.locationDataSource,
    required this.remoteDataSource,
  });

  final LocationDataSource locationDataSource;
  final PlacesRemoteDataSource remoteDataSource;

  @override
  Future<UserLocation> getCurrentLocation() async {
    try {
      return await locationDataSource.getCurrentLocation();
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<List<NearbyStore>> getNearbyStores({
    required double latitude,
    required double longitude,
    required UserLocation userLocation,
    required int radiusMeters,
  }) async {
    try {
      final stores = await remoteDataSource.getNearbyStores(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      return stores
          .map(
            (store) => store.copyWith(
              distanceMeters: Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                store.latitude,
                store.longitude,
              ),
            ),
          )
          .toList(growable: false);
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }
}
