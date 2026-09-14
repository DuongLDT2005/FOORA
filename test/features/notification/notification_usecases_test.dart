import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/notification/domain/entities/app_notification.dart';
import 'package:foora/features/notification/domain/repositories/notification_repository.dart';
import 'package:foora/features/notification/domain/usecases/get_notifications.dart';
import 'package:foora/features/notification/domain/usecases/mark_notification_as_read.dart';
import 'package:foora/features/notification/domain/usecases/register_device.dart';
import 'package:foora/features/notification/domain/usecases/unregister_device.dart';

class MockNotificationRepository implements NotificationRepository {
  String? registeredUserId;
  String? unregisteredUserId;
  final List<AppNotification> notifications = [];

  @override
  Future<void> registerDevice({required String userId}) async {
    registeredUserId = userId;
  }

  @override
  Future<void> unregisterDevice({required String userId}) async {
    unregisteredUserId = userId;
  }

  @override
  Stream<List<AppNotification>> getNotifications(String userId) {
    return Stream.value(notifications);
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead({required String userId}) async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }
}

void main() {
  group('Notification Domain UseCases Tests', () {
    late MockNotificationRepository mockRepository;

    setUp(() {
      mockRepository = MockNotificationRepository();
    });

    test(
      'RegisterDeviceUseCase should invoke repository registerDevice',
      () async {
        final useCase = RegisterDeviceUseCase(mockRepository);
        await useCase(userId: 'test-user-123');

        expect(mockRepository.registeredUserId, 'test-user-123');
      },
    );

    test(
      'UnregisterDeviceUseCase should invoke repository unregisterDevice',
      () async {
        final useCase = UnregisterDeviceUseCase(mockRepository);
        await useCase(userId: 'test-user-123');

        expect(mockRepository.unregisteredUserId, 'test-user-123');
      },
    );

    test(
      'GetNotificationsUseCase should return stream of notifications',
      () async {
        final notif = AppNotification(
          id: 'notif-1',
          title: 'Cảnh báo hết hạn',
          message: 'Sữa tươi sắp hết hạn sau 2 ngày.',
          type: NotificationType.upcomingExpiration,
          isRead: false,
          createdAt: DateTime.now(),
        );
        mockRepository.notifications.add(notif);

        final useCase = GetNotificationsUseCase(mockRepository);
        final stream = useCase('test-user-123');

        final list = await stream.first;
        expect(list, hasLength(1));
        expect(list.first.title, 'Cảnh báo hết hạn');
      },
    );

    test(
      'MarkNotificationAsReadUseCase should mark single and all notifications',
      () async {
        final notif1 = AppNotification(
          id: 'notif-1',
          title: 'Notif 1',
          message: 'Message 1',
          type: NotificationType.system,
          isRead: false,
          createdAt: DateTime.now(),
        );
        final notif2 = AppNotification(
          id: 'notif-2',
          title: 'Notif 2',
          message: 'Message 2',
          type: NotificationType.system,
          isRead: false,
          createdAt: DateTime.now(),
        );
        mockRepository.notifications.addAll([notif1, notif2]);

        final useCase = MarkNotificationAsReadUseCase(mockRepository);

        await useCase(userId: 'test-user-123', notificationId: 'notif-1');
        expect(mockRepository.notifications[0].isRead, isTrue);
        expect(mockRepository.notifications[1].isRead, isFalse);

        await useCase.markAll(userId: 'test-user-123');
        expect(mockRepository.notifications[1].isRead, isTrue);
      },
    );
  });
}
