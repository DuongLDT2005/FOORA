import 'package:meta/meta.dart';

@immutable
class ShoppingList {
  final String id;
  final String householdId;
  final String name;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingList({
    required this.id,
    required this.householdId,
    required this.name,
    this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  ShoppingList copyWith({
    String? id,
    String? householdId,
    String? name,
    String? note,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingList &&
        other.id == id &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, updatedAt);
}
