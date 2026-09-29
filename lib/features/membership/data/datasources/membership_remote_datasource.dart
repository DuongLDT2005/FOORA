import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/membership_plan_model.dart';
import '../models/subscription_model.dart';

abstract class MembershipRemoteDataSource {
  Future<MembershipPlanModel> getMembershipPlan(String membershipId);
  Stream<SubscriptionModel?> watchPremiumSubscription();
  Future<void> updateAutoRenew(bool enabled);
}

class MembershipRemoteDataSourceImpl implements MembershipRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  MembershipRemoteDataSourceImpl({
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  String get _userId {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để quản lý gói.');
    }
    return userId;
  }

  @override
  Future<MembershipPlanModel> getMembershipPlan(String membershipId) async {
    try {
      final document = await firestore
          .collection(FirestoreConstants.memberships)
          .doc(membershipId)
          .get();

      if (!document.exists) {
        throw const NotFoundException('Không tìm thấy gói thành viên.');
      }

      return MembershipPlanModel.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw ServerException.fromFirebase(error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Stream<SubscriptionModel?> watchPremiumSubscription() {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(_userId)
        .collection(FirestoreConstants.subscriptions)
        .doc('payos_premium')
        .snapshots()
        .map(
          (document) => document.exists
              ? SubscriptionModel.fromFirestore(document)
              : null,
        );
  }

  @override
  Future<void> updateAutoRenew(bool enabled) async {
    try {
      final result = await functions
          .httpsCallable('updateAutoRenew')
          .call(<String, dynamic>{'enabled': enabled});
      final envelope = Map<String, dynamic>.from(result.data as Map);
      if (envelope['success'] != true) {
        throw ServerException(
          envelope['error'] as String? ??
              'Không thể cập nhật tự động gia hạn.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw ServerException(
        error.message ?? 'Không thể cập nhật tự động gia hạn.',
        error.code,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException('Không thể cập nhật tự động gia hạn: $error');
    }
  }
}
