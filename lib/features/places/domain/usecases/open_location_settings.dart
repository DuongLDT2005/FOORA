import '../repositories/places_repository.dart';

class OpenLocationSettings {
  const OpenLocationSettings(this._repository);

  final PlacesRepository _repository;

  Future<void> call({required bool appSettings}) =>
      _repository.openLocationSettings(appSettings: appSettings);
}
