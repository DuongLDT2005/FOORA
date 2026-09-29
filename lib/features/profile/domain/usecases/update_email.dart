import '../repositories/profile_repository.dart';

class UpdateEmailUseCase {
  final ProfileRepository repository;

  UpdateEmailUseCase(this.repository);

  Future<void> call({
    required String newEmail,
    required String currentPassword,
  }) {
    return repository.updateEmail(
      newEmail: newEmail,
      currentPassword: currentPassword,
    );
  }
}
