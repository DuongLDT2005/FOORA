import 'package:meta/meta.dart';

import '../../../../core/constants/app_enums.dart';

/// One purchased item to move into the fridge, as confirmed by the user.
/// Expiry is computed by the backend from shelf-life rules.
@immutable
class ImportShoppingItemRequest {
  final String shoppingItemId;
  final StorageLocationCode storageLocation;
  final String categoryId;
  final double actualQuantity;
  final DateTime? purchaseDate;

  const ImportShoppingItemRequest({
    required this.shoppingItemId,
    required this.storageLocation,
    required this.categoryId,
    required this.actualQuantity,
    this.purchaseDate,
  });
}
