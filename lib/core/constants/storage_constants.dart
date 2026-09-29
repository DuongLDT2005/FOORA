class StorageConstants {
  StorageConstants._();

  // Storage Folders
  static const String receiptsPath = 'receipts';
  static const String foodsPath = 'foods';
  static const String usersPath = 'users';
  static const String avatarsPath = 'avatar';
  static const String bugReportsPath = 'bug_reports';

  static String userAvatar(String userId, String fileName) =>
      '$usersPath/$userId/$avatarsPath/$fileName';

  static String bugReportScreenshot(String userId, String fileName) =>
      '$bugReportsPath/$userId/$fileName';
}
