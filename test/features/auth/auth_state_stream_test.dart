import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:foora/features/auth/data/models/user_model.dart';

class _FakeUser implements fb.User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => '$uid@foora.test';

  @override
  String? get displayName => uid;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements fb.FirebaseAuth {
  final _changes = StreamController<fb.User?>.broadcast();

  @override
  fb.User? currentUser;

  void emit(fb.User? user) {
    currentUser = user;
    _changes.add(user);
  }

  @override
  Stream<fb.User?> authStateChanges() => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'switching accounts emits the new user even though the previous '
    'profile listener never completes',
    () async {
      final firestore = FakeFirebaseFirestore();
      for (final uid in ['user-a', 'user-b']) {
        await firestore.collection('users').doc(uid).set({
          'fullName': uid,
          'email': '$uid@foora.test',
          'activeHouseholdId': 'home-$uid',
        });
      }
      final auth = _FakeAuth();
      final dataSource = AuthRemoteDataSourceImpl(
        firebaseAuth: auth,
        firestore: firestore,
      );

      final events = <UserModel?>[];
      final sub = dataSource.authStateChanges.listen(events.add);
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      auth.emit(_FakeUser('user-a'));
      await pumpEventQueue();
      expect(events.last?.activeHouseholdId, 'home-user-a');

      auth.emit(null);
      await settle();
      expect(events.last, isNull);

      auth.emit(_FakeUser('user-b'));
      await pumpEventQueue();
      expect(events.last?.id, 'user-b');
      expect(events.last?.activeHouseholdId, 'home-user-b');

      await sub.cancel();
    },
  );
}
