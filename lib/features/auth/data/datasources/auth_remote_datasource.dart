import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

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

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final fb.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Stream<UserModel?> get authStateChanges {
    return firebaseAuth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) {
        return Stream.value(null);
      }
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
            return userModel;
          });
    });
  }

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

      // Save fullName into Firestore user document using merge: true
      await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .set({
            'fullName': fullName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also update default household name if user doc already has activeHouseholdId
      final userSnapshot = await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .get();
      final activeHouseholdId =
          userSnapshot.data()?['activeHouseholdId'] as String?;
      if (activeHouseholdId != null && activeHouseholdId.isNotEmpty) {
        await firestore
            .collection(FirestoreConstants.households)
            .doc(activeHouseholdId)
            .update({
              'name': 'Tủ lạnh của $fullName',
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((_) => null);
      }

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

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Đã hủy đăng nhập Google.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthException(
          'Đăng nhập Google thất bại. Không tìm thấy thông tin người dùng.',
        );
      }

      final resolvedName =
          fbUser.displayName ?? googleUser.displayName ?? '';

      // Save fullName into Firestore user document using merge: true
      if (resolvedName.isNotEmpty) {
        await firestore
            .collection(FirestoreConstants.users)
            .doc(fbUser.uid)
            .set({
              'fullName': resolvedName,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        final userSnapshot = await firestore
            .collection(FirestoreConstants.users)
            .doc(fbUser.uid)
            .get();
        final activeHouseholdId =
            userSnapshot.data()?['activeHouseholdId'] as String?;
        if (activeHouseholdId != null && activeHouseholdId.isNotEmpty) {
          await firestore
              .collection(FirestoreConstants.households)
              .doc(activeHouseholdId)
              .update({
                'name': 'Tủ lạnh của $resolvedName',
                'updatedAt': FieldValue.serverTimestamp(),
              }).catchError((_) => null);
        }
      }

      final doc = await firestore
          .collection(FirestoreConstants.users)
          .doc(fbUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userModel = UserModel.fromFirestore(doc);
        if (!userModel.isActive) {
          await firebaseAuth.signOut();
          await googleSignIn.signOut();
          throw const AuthException('Tài khoản của bạn đã bị vô hiệu hóa.');
        }
        return userModel;
      }

      // If document is being created via Cloud Function trigger or not synced yet:
      return UserModel(
        id: fbUser.uid,
        fullName: resolvedName,
        email: fbUser.email ?? googleUser.email,
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
