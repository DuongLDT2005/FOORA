import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/membership_plan_model.dart';
import '../models/subscription_model.dart';

/// Contract for membership / subscription data access.
abstract class MembershipRemoteDataSource {
  /// Loads a plan definition (price, duration, limits).
  Future<MembershipPlanModel> getMembershipPlan(String membershipId);

  /// Streams the current user's active subscription, or `null` if none.
  Stream<SubscriptionModel?> watchPremiumSubscription();
}

/// Firestore implementation of [MembershipRemoteDataSource].
class MembershipRemoteDataSourceImpl implements MembershipRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  MembershipRemoteDataSourceImpl({required this.auth, required this.firestore});

  String get _userId {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('Vui lòng đăng nhập để quản lý gói.');
    }
    return userId;
  }

  /// Reads `memberships/{membershipId}`.
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

  /// Listens to the user's `active` subscriptions and emits the one whose
  /// entitlement window is still open with the furthest `endDate`.
  @override
  Stream<SubscriptionModel?> watchPremiumSubscription() {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(_userId)
        .collection(FirestoreConstants.subscriptions)
        .where('status', isEqualTo: SubscriptionStatus.active.value)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          SubscriptionModel? latest;
          for (final document in snapshot.docs) {
            final subscription = SubscriptionModel.fromFirestore(document);
            if (!subscription.isEntitledAt(now)) continue;
            if (latest == null ||
                subscription.endDate.isAfter(latest.endDate)) {
              latest = subscription;
            }
          }
          return latest;
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw ServerException.fromFirebase(error);
          }
          throw ServerException(error.toString());
        });
  }
}
