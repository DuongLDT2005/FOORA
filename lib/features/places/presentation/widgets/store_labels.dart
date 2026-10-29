import '../../domain/entities/nearby_store.dart';

/// The filter chips shown above the store list.
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

/// Straight-line distance label, e.g. "≈ 850 m" or "≈ 1.2 km".
String formatStoreDistance(double distanceMeters) {
  if (distanceMeters < 1000) return '≈ ${distanceMeters.round()} m';
  return '≈ ${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
