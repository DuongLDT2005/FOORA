import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/errors/exceptions.dart';
import 'package:foora/core/errors/failures.dart';
import 'package:foora/features/places/domain/entities/nearby_store.dart';
import 'package:foora/features/places/domain/entities/user_location.dart';
import 'package:foora/features/places/domain/repositories/places_repository.dart';
import 'package:foora/features/places/domain/usecases/get_nearby_stores.dart';

const userLocation = UserLocation(
  latitude: 10.77,
  longitude: 106.69,
  accuracy: 12,
);

void main() {
  test(
    'sorts stores by actual distance and keeps only the requested radius',
    () async {
      final repository = _FakePlacesRepository([
        [
          _store('middle', 2000),
          _store('near', 1200),
          _store('far', 2300),
          _store('closest', 100),
          _store('next', 200),
          _store('outside', 5100),
        ],
      ]);

      final result = await GetNearbyStores(repository)(
        userLocation: userLocation,
      );

      expect(result.map((store) => store.id), [
        'closest',
        'next',
        'near',
        'middle',
        'far',
      ]);
      expect(repository.requestedRadii, [3000]);
    },
  );

  test(
    'expands its search exactly once when fewer than five stores are found',
    () async {
      final repository = _FakePlacesRepository([
        [_store('one', 200)],
        [
          _store('five', 500),
          _store('four', 400),
          _store('three', 300),
          _store('two', 200),
          _store('one', 100),
        ],
      ]);

      final result = await GetNearbyStores(repository)(
        userLocation: userLocation,
      );

      expect(repository.requestedRadii, [3000, 5000]);
      expect(result.map((store) => store.id), [
        'one',
        'two',
        'three',
        'four',
        'five',
      ]);
    },
  );

  test('filters an area search by distance to the searched centre', () async {
    // The searched area is ~11 km from the user, so every store is far from
    // the user but within 3 km of the searched centre.
    const centreLatitude = 10.87;
    final repository = _FakePlacesRepository([
      [
        for (var i = 0; i < 5; i++)
          _storeAt('area-$i', centreLatitude + i * 0.002, 11000),
        _storeAt('outside', centreLatitude + 0.05, 16000),
      ],
    ]);

    final result = await GetNearbyStores(repository)(
      userLocation: userLocation,
      searchLatitude: centreLatitude,
      searchLongitude: userLocation.longitude,
    );

    expect(repository.requestedRadii, [3000]);
    expect(result.map((store) => store.id), [
      'area-0',
      'area-1',
      'area-2',
      'area-3',
      'area-4',
    ]);
  });

  test('maps a location exception to a location failure', () {
    final failure = Failure.fromException(
      LocationException(LocationErrorCode.deniedForever),
    );

    expect(failure, isA<LocationFailure>());
    expect(
      (failure as LocationFailure).locationCode,
      LocationErrorCode.deniedForever,
    );
  });
}

NearbyStore _storeAt(String id, double latitude, double distanceMeters) =>
    NearbyStore(
      id: id,
      name: id,
      kind: StoreKind.supermarket,
      latitude: latitude,
      longitude: userLocation.longitude,
      distanceMeters: distanceMeters,
    );

NearbyStore _store(String id, double distanceMeters) => NearbyStore(
  id: id,
  name: id,
  kind: StoreKind.supermarket,
  latitude: 0,
  longitude: 0,
  distanceMeters: distanceMeters,
);

class _FakePlacesRepository implements PlacesRepository {
  _FakePlacesRepository(this._responses);

  final List<List<NearbyStore>> _responses;
  final List<int> requestedRadii = [];
  var _callCount = 0;

  @override
  Future<UserLocation> getCurrentLocation() async => userLocation;

  @override
  Future<void> openLocationSettings({required bool appSettings}) async {}

  @override
  Future<List<NearbyStore>> getNearbyStores({
    required double latitude,
    required double longitude,
    required UserLocation userLocation,
    required int radiusMeters,
  }) async {
    requestedRadii.add(radiusMeters);
    return _responses[_callCount++];
  }
}
