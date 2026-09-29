import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bug_report.dart';

class BugReportModel extends BugReport {
  const BugReportModel({
    required super.id,
    required super.userId,
    required super.userEmail,
    required super.category,
    required super.title,
    required super.description,
    super.screenshotUrl,
    super.deviceInfo,
    required super.createdAt,
  });

  factory BugReportModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BugReportModel.fromJson(data, id: doc.id);
  }

  factory BugReportModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return BugReportModel(
      id: id ?? json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      screenshotUrl: json['screenshotUrl'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  factory BugReportModel.fromEntity(BugReport entity) {
    return BugReportModel(
      id: entity.id,
      userId: entity.userId,
      userEmail: entity.userEmail,
      category: entity.category,
      title: entity.title,
      description: entity.description,
      screenshotUrl: entity.screenshotUrl,
      deviceInfo: entity.deviceInfo,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'category': category,
      'title': title,
      'description': description,
      if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

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
