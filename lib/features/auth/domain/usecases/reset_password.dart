import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  Future<void> call({required String email}) {
    return _repository.sendPasswordResetEmail(email: email);
  }
}
