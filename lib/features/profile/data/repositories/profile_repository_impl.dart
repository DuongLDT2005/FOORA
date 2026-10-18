import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/bug_report.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/bug_report_model.dart';

/// Implementation of [ProfileRepository]; delegates to [ProfileRemoteDataSource]
/// and converts exceptions into [Failure]s.
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  /// Streams the user's profile.
  @override
  Stream<Profile> watchProfile(String userId) {
    try {
      return remoteDataSource.watchProfile(userId);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Reads the user's profile once.
  @override
  Future<Profile> getProfile(String userId) async {
    try {
      return await remoteDataSource.getProfile(userId);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Updates profile fields.
  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      await remoteDataSource.updateProfile(
        userId: userId,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Uploads a new avatar and returns its URL.
  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      return await remoteDataSource.uploadAvatar(
        userId: userId,
        filePath: filePath,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Changes the account email.
  @override
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      await remoteDataSource.updateEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Changes the account password.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Sends a bug report.
  @override
  Future<void> submitBugReport(BugReport report, String? screenshotPath) async {
    try {
      await remoteDataSource.submitBugReport(
        BugReportModel.fromEntity(report),
        screenshotPath,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Deletes the account.
  @override
  Future<void> deleteAccount({String? password}) async {
    try {
      await remoteDataSource.deleteAccount(password: password);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
