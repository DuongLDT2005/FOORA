import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository _repository;

  const SignInWithGoogleUseCase(this._repository);

  Future<User> call() {
    return _repository.signInWithGoogle();
  }
}
