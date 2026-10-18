/// Recommended storage duration from `shelf_life_rules` or a category's
/// `defaultShelfLife` (docs/DATABASE.md).
///
/// [unit] is one of `days`, `weeks`, `months`, `years`. A `null` [maxValue]
/// means storage at this location is not recommended.
class ShelfLifeDuration {
  final num? minValue;
  final num? maxValue;
  final String? unit;

  const ShelfLifeDuration({this.minValue, this.maxValue, this.unit});

  /// Whether a usable duration exists (prefers [maxValue], then [minValue]).
  bool get isRecommended => (maxValue ?? minValue) != null && unit != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShelfLifeDuration &&
        other.minValue == minValue &&
        other.maxValue == maxValue &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(minValue, maxValue, unit);
}
