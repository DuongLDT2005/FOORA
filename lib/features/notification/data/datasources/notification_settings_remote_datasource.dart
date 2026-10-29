import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';

/// Reads and writes `users/{uid}.notificationSettings`.
abstract class NotificationSettingsRemoteDataSource {
  /// Emits the raw settings map, or null when the field is missing.
  Stream<Map<String, dynamic>?> watch(String userId);

  Future<void> save(String userId, Map<String, dynamic> settings);
}

class NotificationSettingsRemoteDataSourceImpl
    implements NotificationSettingsRemoteDataSource {
  final FirebaseFirestore firestore;

  const NotificationSettingsRemoteDataSourceImpl({required this.firestore});

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      firestore.collection(FirestoreConstants.users).doc(userId);

  @override
  Stream<Map<String, dynamic>?> watch(String userId) {
    return _userRef(userId).snapshots().map((doc) {
      final raw = doc.data()?['notificationSettings'];
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    });
  }

  @override
  Future<void> save(String userId, Map<String, dynamic> settings) async {
    try {
      await _userRef(userId).update({
        'notificationSettings': {
          ...settings,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } on FirebaseException catch (e) {
      throw ServerException.fromFirebase(e);
    }
  }
}
