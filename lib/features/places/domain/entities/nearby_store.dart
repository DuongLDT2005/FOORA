import 'package:meta/meta.dart';

enum StoreKind { supermarket, convenience, greengrocer, butcher, marketplace }

@immutable
class NearbyStore {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.address,
    this.openingHours,
  });

  final String id;
  final String name;
  final StoreKind kind;
  final double latitude;
  final double longitude;

  /// Straight-line distance from the user's location.
  final double distanceMeters;
  final String? address;
  final String? openingHours;

  NearbyStore copyWith({double? distanceMeters}) => NearbyStore(
    id: id,
    name: name,
    kind: kind,
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    address: address,
    openingHours: openingHours,
  );
}
