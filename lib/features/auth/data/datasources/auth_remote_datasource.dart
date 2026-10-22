import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_model.dart';

/// Contract for all remote authentication operations (Firebase Auth + Firestore).
abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  });
  Future<UserModel> signInWithGoogle();
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> logout();
}

/// Firebase implementation of [AuthRemoteDataSource].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final fb.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  /// Emits the signed-in user (merged with their Firestore profile) whenever
  /// the Firebase auth state changes, or `null` after sign-out.
  @override
  Stream<UserModel?> get authStateChanges {
    // Switch to the new account's profile listener on every auth change.
    // `asyncExpand` waited for the previous listener to finish, but Firestore
    // snapshot streams never complete (on web they stay open even after the
    // permission-denied error at sign-out), so the next account's events were
    // queued forever and screens kept querying the old household.
    late final StreamController<UserModel?> controller;
    StreamSubscription<fb.User?>? authSub;
    StreamSubscription<UserModel?>? profileSub;

    controller = StreamController<UserModel?>(
      onListen: () {
        authSub = firebaseAuth.authStateChanges().listen((fbUser) {
          final previous = profileSub;
          profileSub = null;
          previous?.cancel();

          if (fbUser == null) {
            controller.add(null);
            return;
          }
          profileSub = _watchProfile(fbUser).listen(
            controller.add,
            onError: (Object error, StackTrace stackTrace) {
              // The listener of an account that just signed out fails with
              // permission-denied; that is expected, not an app error.
              if (firebaseAuth.currentUser?.uid != fbUser.uid) return;
              controller.addError(error, stackTrace);
            },
          );
        }, onError: controller.addError);
      },
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Live profile of [fbUser], merged from `users/{uid}`.
  Stream<UserModel?> _watchProfile(fb.User fbUser) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(fbUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists || snapshot.data() == null) {
            return UserModel(
              id: fbUser.uid,
              fullName: fbUser.displayName ?? '',
              email: fbUser.email ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
          final userModel = UserModel.fromFirestore(snapshot);
          if (!userModel.isActive) {
            await firebaseAuth.signOut();
            return null;
          }
          await _syncVerifiedEmail(fbUser, userModel.email);
          return userModel;
        });
  }

  /// Copies the Auth email into `users/{uid}.email` once Firebase Auth has
  /// verified it (e.g. after a `verifyBeforeUpdateEmail` link was confirmed).
  /// Firestore rules only accept an email equal to the verified token email.
  Future<void> _syncVerifiedEmail(fb.User fbUser, String storedEmail) async {
    final authEmail = fbUser.email;
    if (authEmail == null ||
        authEmail == storedEmail ||
        !fbUser.emailVerified) {
      return;
    }
    try {
      await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .update({
            'email': authEmail,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e, st) {
      AppLogger.w('Could not sync verified email for ${fbUser.uid}: $e');
      AppLogger.e('Email sync failed', e, st);
    }
  }

  /// Saves the display name and renames the default household created by the
  /// `onUserCreated` trigger. Only called for brand-new accounts, so a household
  /// the user renamed later is never overwritten.
  Future<void> _saveNewUserProfileName(String uid, String fullName) async {
    final userRef = firestore.collection(FirestoreConstants.users).doc(uid);
    await userRef.set({
      'fullName': fullName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userSnapshot = await userRef.get();
    final activeHouseholdId =
        userSnapshot.data()?['activeHouseholdId'] as String?;
    if (activeHouseholdId == null || activeHouseholdId.isEmpty) {
      // The trigger has not finished yet; it reads `fullName` when it runs.
      AppLogger.i('Default household for $uid not created yet; skip rename.');
      return;
    }
    try {
      await firestore
          .collection(FirestoreConstants.households)
          .doc(activeHouseholdId)
          .update({
            'name': 'Tủ lạnh của $fullName',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (e, st) {
      // Renaming is cosmetic; the account itself was created successfully.
      AppLogger.e(
        'Could not rename default household $activeHouseholdId',
        e,
        st,
      );
    }
  }

  /// Synchronously returns the currently signed-in user, or `null`.
  @override
  UserModel? get currentUser {
    final fbUser = firebaseAuth.currentUser;
    if (fbUser == null) return null;
    return UserModel(
      id: fbUser.uid,
      fullName: fbUser.displayName ?? '',
      email: fbUser.email ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Signs in with email/password, then loads the user's Firestore profile.
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException(
          'Đăng nhập thất bại. Không tìm thấy thông tin người dùng.',
        );
      }

      final doc = await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userModel = UserModel.fromFirestore(doc);
        if (!userModel.isActive) {
          await firebaseAuth.signOut();
          throw const AuthException('Tài khoản của bạn đã bị vô hiệu hóa.');
        }
        return userModel;
      }

      // If document doesn't exist yet, construct baseline
      return UserModel(
        id: fbUser.uid,
        fullName: fbUser.displayName ?? '',
        email: fbUser.email ?? email,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Creates a Firebase Auth account, sets the display name and stores the
  /// profile in Firestore (the default household is created by a Cloud Function).
  @override
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException('Đăng ký thất bại. Vui lòng thử lại.');
      }

      await fbUser.updateDisplayName(fullName);

      await _saveNewUserProfileName(fbUser.uid, fullName);

      final now = DateTime.now();
      return UserModel(
        id: fbUser.uid,
        fullName: fullName,
        email: email,
        createdAt: now,
        updatedAt: now,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Google sign-in: native Google Sign-In on mobile, popup provider on web.
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      fb.UserCredential userCredential;
      String resolvedName = '';
      String? resolvedEmail;

      if (kIsWeb) {
        // On Web, use Firebase Auth's native popup provider to prevent null accessToken / idToken issues
        final googleProvider = fb.GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await firebaseAuth.signInWithPopup(googleProvider);
        final fbUser = userCredential.user;
        if (fbUser == null) {
          throw const AuthException(
            'Đăng nhập Google thất bại. Không tìm thấy thông tin người dùng.',
          );
        }
        resolvedName = fbUser.displayName ?? '';
        resolvedEmail = fbUser.email;
      } else {
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthException('Đã hủy đăng nhập Google.');
        }

        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await firebaseAuth.signInWithCredential(credential);
        final fbUser = userCredential.user;
        if (fbUser == null) {
          throw const AuthException(
            'Đăng nhập Google thất bại. Không tìm thấy thông tin người dùng.',
          );
        }
        resolvedName = fbUser.displayName ?? googleUser.displayName ?? '';
        resolvedEmail = fbUser.email ?? googleUser.email;
      }

      final fbUser = userCredential.user!;

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      if (isNewUser && resolvedName.isNotEmpty) {
        await _saveNewUserProfileName(fbUser.uid, resolvedName);
      }

      final doc = await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userModel = UserModel.fromFirestore(doc);
        if (!userModel.isActive) {
          await firebaseAuth.signOut();
          await googleSignIn.signOut().catchError((_) => null);
          throw const AuthException('Tài khoản của bạn đã bị vô hiệu hóa.');
        }
        return userModel;
      }

      // If document is being created via Cloud Function trigger or not synced yet:
      return UserModel(
        id: fbUser.uid,
        fullName: resolvedName,
        email: resolvedEmail ?? fbUser.email ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Asks Firebase to email a password-reset link.
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Signs out of Firebase Auth and Google Sign-In.
  @override
  Future<void> logout() async {
    try {
      await Future.wait([
        firebaseAuth.signOut(),
        GoogleSignIn().signOut().catchError((_) => null),
      ]);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
