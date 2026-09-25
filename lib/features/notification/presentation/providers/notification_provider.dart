import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_notification_as_read.dart';
import '../../domain/usecases/register_device.dart';
import '../../domain/usecases/unregister_device.dart';

final currentNotificationUserIdProvider = StreamProvider<String?>((ref) {
  return ref
      .watch(firebaseAuthProvider)
      .authStateChanges()
      .map((user) => user?.uid);
});

// --- Data Layer Providers ---

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
      return NotificationRemoteDataSourceImpl(
        firestore: ref.watch(firestoreProvider),
        messaging: ref.watch(messagingProvider),
        sharedPreferences: ref.watch(sharedPreferencesProvider),
      );
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    remoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
  );
});

// --- Domain Layer UseCase Providers ---

final registerDeviceUseCaseProvider = Provider<RegisterDeviceUseCase>((ref) {
  return RegisterDeviceUseCase(ref.watch(notificationRepositoryProvider));
});

final unregisterDeviceUseCaseProvider = Provider<UnregisterDeviceUseCase>((
  ref,
) {
  return UnregisterDeviceUseCase(ref.watch(notificationRepositoryProvider));
});

final getNotificationsUseCaseProvider = Provider<GetNotificationsUseCase>((
  ref,
) {
  return GetNotificationsUseCase(ref.watch(notificationRepositoryProvider));
});

final markNotificationAsReadUseCaseProvider =
    Provider<MarkNotificationAsReadUseCase>((ref) {
      return MarkNotificationAsReadUseCase(
        ref.watch(notificationRepositoryProvider),
      );
    });

// --- Stream & State Providers ---

/// Stream of all notifications for the given user, sorted newest first
final userNotificationsStreamProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      if (userId.isEmpty) {
        return Stream.value([]);
      }
      return ref.watch(getNotificationsUseCaseProvider)(userId);
    });

/// Count of unread notifications for badge display
final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final notifAsync = ref.watch(userNotificationsStreamProvider(userId));
  return notifAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;

  NotificationActionNotifier(this._repository) : super(const AsyncData(null));

  Future<void> markAsRead(String userId, String notificationId) async {
    await _repository.markAsRead(
      userId: userId,
      notificationId: notificationId,
    );
  }

  Future<void> markAllAsRead(String userId) async {
    await _repository.markAllAsRead(userId: userId);
  }
}

final notificationNotifierProvider =
    StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>((ref) {
      return NotificationActionNotifier(
        ref.watch(notificationRepositoryProvider),
      );
    });
