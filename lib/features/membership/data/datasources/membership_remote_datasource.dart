import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/membership_plan_model.dart';

abstract class MembershipRemoteDataSource {
  Future<MembershipPlanModel> getMembershipPlan(String membershipId);
}

class MembershipRemoteDataSourceImpl implements MembershipRemoteDataSource {
  final FirebaseFirestore firestore;

  MembershipRemoteDataSourceImpl({required this.firestore});

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
}
