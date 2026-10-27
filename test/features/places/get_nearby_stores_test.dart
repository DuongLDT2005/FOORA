import 'package:flutter_test/flutter_test.dart';
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

  test('sorts stores by actual distance and keeps only the requested radius', () async {
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

    final result = await GetNearbyStores(repository)(userLocation: userLocation);

    expect(result.map((store) => store.id), [
      'closest',
      'next',
      'near',
      'middle',
      'far',
    ]);
    expect(repository.requestedRadii, [3000]);
  });

  test('expands its search exactly once when fewer than five stores are found', () async {
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

    final result = await GetNearbyStores(repository)(userLocation: userLocation);

    expect(repository.requestedRadii, [3000, 5000]);
    expect(result.map((store) => store.id), ['one', 'two', 'three', 'four', 'five']);
  });
}

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
