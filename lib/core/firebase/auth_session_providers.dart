import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_constants.dart';
import 'firebase_providers.dart';

/// Raw technical stream of current user's document snapshot from Firestore
final currentUserDocStreamProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
      final auth = ref.watch(firebaseAuthProvider);
      final firestore = ref.watch(firestoreProvider);

      return auth.authStateChanges().asyncExpand((user) {
        if (user == null) {
          return Stream.value(null);
        }
        return firestore
            .collection(FirestoreConstants.users)
            .doc(user.uid)
            .snapshots();
      });
    });

/// Business logic provider: interprets admin role and active status (Testable & Mockable)
final isAdminProvider = Provider<AsyncValue<bool>>((ref) {
  final userDocAsync = ref.watch(currentUserDocStreamProvider);

  return userDocAsync.whenData((snapshot) {
    if (snapshot == null || !snapshot.exists) {
      return false;
    }
    final data = snapshot.data();
    final role = data?['role'] as String?;
    final isActive = data?['isActive'] as bool? ?? true;
    return role == 'admin' && isActive;
  });
});
