import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/bug_report_model.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Stream<ProfileModel> watchProfile(String userId);
  Future<ProfileModel> getProfile(String userId);
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
  Future<void> submitBugReport(BugReportModel report, String? screenshotPath);
  Future<void> deleteAccount({String? password});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;
  final FirebaseStorage storage;

  ProfileRemoteDataSourceImpl({
    required this.firestore,
    required this.firebaseAuth,
    required this.storage,
  });

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

  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref(StorageConstants.userAvatar(userId, fileName));
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Tải ảnh đại diện thất bại: ${e.toString()}');
    }
  }

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

      // Send verification before updating email
      await user.verifyBeforeUpdateEmail(newEmail);

      // Update Firestore user document
      await firestore.collection(FirestoreConstants.users).doc(user.uid).update(
        {'email': newEmail, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Cập nhật email thất bại: ${e.toString()}');
    }
  }

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

  @override
  Future<void> submitBugReport(
    BugReportModel report,
    String? screenshotPath,
  ) async {
    try {
      String? screenshotUrl;
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        final file = File(screenshotPath);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = storage.ref(
          StorageConstants.bugReportScreenshot(report.userId, fileName),
        );
        final uploadTask = await ref.putFile(
          file,
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
