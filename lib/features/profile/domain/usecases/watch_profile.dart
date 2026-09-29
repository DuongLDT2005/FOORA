import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class WatchProfileUseCase {
  final ProfileRepository repository;

  WatchProfileUseCase(this.repository);

  Stream<Profile> call(String userId) {
    return repository.watchProfile(userId);
  }
}
