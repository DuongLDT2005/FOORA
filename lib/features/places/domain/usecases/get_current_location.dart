import '../entities/user_location.dart';
import '../repositories/places_repository.dart';

class GetCurrentLocation {
  const GetCurrentLocation(this._repository);

  final PlacesRepository _repository;

  Future<UserLocation> call() => _repository.getCurrentLocation();
}
