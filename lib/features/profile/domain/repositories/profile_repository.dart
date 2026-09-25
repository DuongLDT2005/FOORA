import '../entities/bug_report.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Stream<Profile> watchProfile(String userId);

  Future<Profile> getProfile(String userId);

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  });

  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  });

  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> submitBugReport(BugReport report, String? screenshotPath);

  Future<void> deleteAccount({String? password});
}
