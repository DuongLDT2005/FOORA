import '../repositories/notification_repository.dart';

class UnregisterDeviceUseCase {
  final NotificationRepository _repository;

  const UnregisterDeviceUseCase(this._repository);

  Future<void> call({required String userId}) {
    return _repository.unregisterDevice(userId: userId);
  }
}
