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
  });

  final String actionId;
  final String type;
  final String name;
  final double? quantity;
  final String? unit;
  final String? categoryId;
  final String? storageLocationId;
  final String? targetItemId;
  final List<AiActionCandidate> candidateBatches;
  final String reviewState;
  final String resolution;
}
