import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/utils/stream_utils.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/presentation/providers/auth_provider.dart';
import 'package:foora/features/profile/domain/entities/profile.dart';
import 'package:foora/features/profile/domain/repositories/profile_repository.dart';
import 'package:foora/features/profile/domain/usecases/watch_profile.dart';
import 'package:foora/features/profile/presentation/providers/profile_provider.dart';

User _user(String id) => User(
  id: id,
  fullName: id,
  email: '$id@foora.test',
  createdAt: _t,
  updatedAt: _t,
);

final _t = DateTime(2026, 10, 1);

/// Emits one profile per uid and, like a Firestore listener, never completes.
class _NeverEndingProfiles implements ProfileRepository {
  final watched = <String>[];

  @override
  Stream<Profile> watchProfile(String userId) {
    watched.add(userId);
    final controller = StreamController<Profile>();
    controller.add(Profile.fromUser(_user(userId)));
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('switchLatest', () {
    test(
      'moves to the next inner stream although the previous never ends',
      () async {
        final source = StreamController<String?>();
        final events = <String>[];
        final sub = switchLatest<String?, String>(source.stream, (uid) {
          if (uid == null) return Stream.value('signed-out');
          final inner = StreamController<String>()..add('profile-$uid');
          return inner.stream; // never closed, like snapshots()
        }).listen(events.add);

        source.add('a');
        await pumpEventQueue();
        source.add(null);
        await pumpEventQueue();
        source.add('b');
        await pumpEventQueue();

        expect(events, ['profile-a', 'signed-out', 'profile-b']);
        await sub.cancel();
      },
    );
  });

  test('profile tab follows the signed-in account after switching', () async {
    final repo = _NeverEndingProfiles();
    final signedIn = StateProvider<User?>((ref) => _user('user-a'));
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(signedIn)),
        watchProfileUseCaseProvider.overrideWithValue(
          WatchProfileUseCase(repo),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentProfileStreamProvider, (_, _) {});

    await pumpEventQueue();
    expect(container.read(currentProfileStreamProvider).value?.id, 'user-a');

    container.read(signedIn.notifier).state = null;
    await pumpEventQueue();
    expect(container.read(currentProfileStreamProvider).value, isNull);

    container.read(signedIn.notifier).state = _user('user-b');
    await pumpEventQueue();
    expect(container.read(currentProfileStreamProvider).value?.id, 'user-b');
    expect(repo.watched, ['user-a', 'user-b']);
  });
}
