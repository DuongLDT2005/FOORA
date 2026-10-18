import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/bug_report_model.dart';
import '../models/profile_model.dart';

/// Contract for profile, account-security and bug-report operations.
abstract class ProfileRemoteDataSource {
  /// Real-time stream of the user's profile document.
  Stream<ProfileModel> watchProfile(String userId);

  /// One-off read of the user's profile.
  Future<ProfileModel> getProfile(String userId);

  /// Updates profile fields (name, phone, avatar URL...).
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  });

  /// Uploads an avatar image to Storage and returns its download URL.
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  });

  /// Changes the login email (requires the current password).
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  });

  /// Changes the password (requires the current password).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Saves a bug report, optionally with a screenshot.
  Future<void> submitBugReport(BugReportModel report, String? screenshotPath);

  /// Permanently deletes the Firebase Auth account.
  Future<void> deleteAccount({String? password});
}

/// Firebase Auth + Firestore + Storage implementation of [ProfileRemoteDataSource].
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;
  final FirebaseStorage storage;

  ProfileRemoteDataSourceImpl({
    required this.firestore,
    required this.firebaseAuth,
    required this.storage,
  });

  /// Listens to `users/{userId}`.
  @override
  Stream<ProfileModel> watchProfile(String userId) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            throw const ServerException('Không tìm thấy tài khoản người dùng.');
          }
          return ProfileModel.fromFirestore(doc);
        });
  }

  /// Reads `users/{userId}` once.
  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final doc = await firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .get();
      if (!doc.exists) {
        throw const ServerException('Không tìm thấy tài khoản người dùng.');
      }
      return ProfileModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Merges the changed fields into `users/{userId}` and syncs the Auth display name.
  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        await user.updateDisplayName(fullName);
        if (avatarUrl != null) {
          await user.updatePhotoURL(avatarUrl);
        }
      }

      final updateData = <String, dynamic>{
        'fullName': fullName,
        'avatarUrl': ?avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Uploads the image to the user's avatar path in Firebase Storage.
  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      // XFile reads both native file paths and web blob URLs.
      final bytes = await XFile(filePath).readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref(StorageConstants.userAvatar(userId, fileName));
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Tải ảnh đại diện thất bại: ${e.toString()}');
    }
  }

  /// Re-authenticates and sends a verification email to the new address.
  ///
  /// Firebase Auth only switches the email after the link is confirmed, so the
  /// Firestore profile is not touched here; the auth data source syncs it once
  /// the new address is verified.
  @override
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthException('Người dùng chưa đăng nhập.');
      }

      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // The email changes only after the user confirms the link.
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Cập nhật email thất bại: ${e.toString()}');
    }
  }

  /// Re-authenticates with the current password, then sets the new one.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthException('Người dùng chưa đăng nhập.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Đổi mật khẩu thất bại: ${e.toString()}');
    }
  }

  /// Uploads the screenshot (if any) to Storage, then writes `bug_reports/{id}`.
  @override
  Future<void> submitBugReport(
    BugReportModel report,
    String? screenshotPath,
  ) async {
    try {
      String? screenshotUrl;
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        final bytes = await XFile(screenshotPath).readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = storage.ref(
          StorageConstants.bugReportScreenshot(report.userId, fileName),
        );
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        screenshotUrl = await uploadTask.ref.getDownloadURL();
      }

      final reportModel = BugReportModel(
        id: report.id,
        userId: report.userId,
        userEmail: report.userEmail,
        category: report.category,
        title: report.title,
        description: report.description,
        screenshotUrl: screenshotUrl ?? report.screenshotUrl,
        deviceInfo: report.deviceInfo,
        createdAt: report.createdAt,
      );

      final docRef = report.id.isEmpty
          ? firestore.collection(FirestoreConstants.bugReports).doc()
          : firestore.collection(FirestoreConstants.bugReports).doc(report.id);

      await docRef.set(reportModel.toFirestore());
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Gửi báo cáo lỗi thất bại: ${e.toString()}');
    }
  }

  /// Re-authenticates (if a password is given) and deletes the Auth user.
  @override
  Future<void> deleteAccount({String? password}) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('Người dùng chưa đăng nhập.');
      }

      if (password != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }

      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Xóa tài khoản thất bại: ${e.toString()}');
    }
  }
}
