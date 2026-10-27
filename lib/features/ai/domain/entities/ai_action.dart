import 'package:meta/meta.dart';

@immutable
class AiActionCandidate {
  const AiActionCandidate({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expirationDate,
  });

  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final String? expirationDate;
}

@immutable
class AiAction {
  const AiAction({
    required this.actionId,
    required this.type,
    required this.name,
    required this.candidateBatches,
    required this.reviewState,
    required this.resolution,
    this.quantity,
    this.unit,
    this.categoryId,
    this.storageLocationId,
    this.targetItemId,
    this.foodId,
    this.photoUrl,
    this.spokenName,
    this.expirationDate,
  });

  final String actionId;
  final String type;
  final String name;
  final double? quantity;
  final String? unit;
  final String? categoryId;
  final String? storageLocationId;
  final String? targetItemId;

  /// add_inventory: `foods` entry matched on the server, as in receipt scans.
  final String? foodId;
  final String? photoUrl;

  /// add_inventory: the user's wording when the catalog name differs.
  final String? spokenName;

  /// add_inventory: estimated expiry `YYYY-MM-DD` from shelf-life rules.
  final String? expirationDate;
  final List<AiActionCandidate> candidateBatches;
  final String reviewState;
  final String resolution;
}
