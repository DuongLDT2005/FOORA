class BugReport {
  final String id;
  final String userId;
  final String userEmail;
  final String category;
  final String title;
  final String description;
  final String? screenshotUrl;
  final String? deviceInfo;
  final DateTime createdAt;

  const BugReport({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.category,
    required this.title,
    required this.description,
    this.screenshotUrl,
    this.deviceInfo,
    required this.createdAt,
  });

  BugReport copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? category,
    String? title,
    String? description,
    String? screenshotUrl,
    String? deviceInfo,
    DateTime? createdAt,
  }) {
    return BugReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
