import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<User> call({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _repository.register(
      fullName: fullName,
      email: email,
      password: password,
    );
  }
}
