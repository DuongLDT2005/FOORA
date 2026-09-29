import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<void> call({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) {
    return repository.updateProfile(
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
  }
}
