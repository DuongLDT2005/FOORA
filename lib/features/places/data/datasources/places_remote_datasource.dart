import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/nearby_store_model.dart';

abstract class PlacesRemoteDataSource {
  Future<List<NearbyStoreModel>> getNearbyStores({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  });
}

class PlacesRemoteDataSourceImpl implements PlacesRemoteDataSource {
  const PlacesRemoteDataSourceImpl(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<NearbyStoreModel>> getNearbyStores({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('getNearbyStores')
          .call<Map<String, dynamic>>({
            'lat': latitude,
            'lng': longitude,
            'radiusMeters': radiusMeters,
          });
      final data = result.data;
      if (data['success'] != true) {
        throw ServerException(data['message'] as String? ?? 'Không thể tìm cửa hàng gần đây.');
      }
      final payload = data['data'] as Map<String, dynamic>? ?? const {};
      final stores = payload['stores'] as List<dynamic>? ?? const [];
      return stores
          .whereType<Map<String, dynamic>>()
          .map(NearbyStoreModel.fromJson)
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      throw ServerException(error.message ?? 'Không thể tải cửa hàng gần đây.', error.code);
    }
  }
}
