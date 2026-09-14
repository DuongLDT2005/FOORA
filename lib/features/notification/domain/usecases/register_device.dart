import '../repositories/notification_repository.dart';

class RegisterDeviceUseCase {
  final NotificationRepository _repository;

  const RegisterDeviceUseCase(this._repository);

  Future<void> call({required String userId}) {
    return _repository.registerDevice(userId: userId);
  }
}
