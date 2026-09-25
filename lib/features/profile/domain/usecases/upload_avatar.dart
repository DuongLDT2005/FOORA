import '../repositories/profile_repository.dart';

class UploadAvatarUseCase {
  final ProfileRepository repository;

  UploadAvatarUseCase(this.repository);

  Future<String> call({required String userId, required String filePath}) {
    return repository.uploadAvatar(userId: userId, filePath: filePath);
  }
}
