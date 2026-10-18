import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/household.dart';

/// Data model for the `households/{householdId}` Firestore document.
class HouseholdModel extends Household {
  const HouseholdModel({
    required super.id,
    required super.name,
    required super.ownerId,
    required super.members,
    super.activeItemCount = 0,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a model from a Firestore snapshot.
  factory HouseholdModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return HouseholdModel.fromJson(data, id: doc.id);
  }

  /// Builds a model from a raw map; [id] overrides the `id` field if given.
  factory HouseholdModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return HouseholdModel(
      id: id ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      activeItemCount: (json['activeItemCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Wraps a domain [Household] for serialization.
  factory HouseholdModel.fromEntity(Household household) {
    return HouseholdModel(
      id: household.id,
      name: household.name,
      ownerId: household.ownerId,
      members: household.members,
      activeItemCount: household.activeItemCount,
      createdAt: household.createdAt,
      updatedAt: household.updatedAt,
    );
  }

  /// Serializes to a Firestore map (dates as [Timestamp]).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'members': members,
      'activeItemCount': activeItemCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Serializes to a JSON map (dates as ISO-8601 strings).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'members': members,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Accepts a Timestamp, ISO string or epoch millis; falls back to now.
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}
