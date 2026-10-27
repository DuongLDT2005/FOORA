import 'package:meta/meta.dart';

enum StoreKind { supermarket, convenience, greengrocer, butcher, marketplace }

enum StoreFilter { all, supermarket, convenience, marketplace }

extension StoreKindLabels on StoreKind {
  String get label => switch (this) {
    StoreKind.supermarket => 'Siêu thị',
    StoreKind.convenience => 'Cửa hàng tiện lợi',
    StoreKind.greengrocer => 'Rau củ',
    StoreKind.butcher => 'Thịt tươi',
    StoreKind.marketplace => 'Chợ',
  };
}

extension StoreFilterLabels on StoreFilter {
  String get label => switch (this) {
    StoreFilter.all => 'Tất cả',
    StoreFilter.supermarket => 'Siêu thị',
    StoreFilter.convenience => 'Tiện lợi',
    StoreFilter.marketplace => 'Chợ',
  };

  bool includes(StoreKind kind) => switch (this) {
    StoreFilter.all => true,
    StoreFilter.supermarket => kind == StoreKind.supermarket,
    StoreFilter.convenience => kind == StoreKind.convenience,
    StoreFilter.marketplace => kind == StoreKind.marketplace,
  };
}

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
