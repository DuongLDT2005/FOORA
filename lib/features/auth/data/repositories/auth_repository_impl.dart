import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<User?> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  User? get currentUser => remoteDataSource.currentUser;

  @override
  Future<User> login({required String email, required String password}) async {
    try {
      return await remoteDataSource.login(email: email, password: password);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      return await remoteDataSource.register(
        fullName: fullName,
        email: email,
        password: password,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      return await remoteDataSource.signInWithGoogle();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email: email);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await remoteDataSource.logout();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
