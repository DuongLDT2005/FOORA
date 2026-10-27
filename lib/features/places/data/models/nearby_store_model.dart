import '../../domain/entities/nearby_store.dart';

class NearbyStoreModel extends NearbyStore {
  const NearbyStoreModel({
    required super.id,
    required super.name,
    required super.kind,
    required super.latitude,
    required super.longitude,
    super.address,
    super.openingHours,
  }) : super(distanceMeters: 0);

  factory NearbyStoreModel.fromJson(Map<String, dynamic> json) {
    return NearbyStoreModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Siêu thị',
      kind: StoreKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => StoreKind.supermarket,
      ),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      openingHours: json['openingHours'] as String?,
    );
  }
}
