import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/core/utils/input_validators.dart';
import 'package:foora/features/auth/domain/entities/user.dart';
import 'package:foora/features/auth/domain/repositories/auth_repository.dart';
import 'package:foora/features/auth/domain/usecases/login.dart';
import 'package:foora/features/auth/domain/usecases/logout.dart';
import 'package:foora/features/auth/domain/usecases/register.dart';
import 'package:foora/features/auth/domain/usecases/reset_password.dart';

class MockAuthRepository implements AuthRepository {
  User? mockUser;
  bool isLoggedOut = false;
  String? resetEmailSentTo;

  @override
  Stream<User?> get authStateChanges => Stream.value(mockUser);

  @override
  User? get currentUser => mockUser;

  @override
  Future<User> login({required String email, required String password}) async {
    if (password == 'wrong_pass') {
      throw Exception('Invalid credentials');
    }
    return mockUser ??
        User(
          id: 'test-user-id',
          fullName: 'Test User',
          email: email,
          role: UserRole.member,
          membershipId: 'free',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return User(
      id: 'new-user-id',
      fullName: fullName,
      email: email,
      role: UserRole.member,
      membershipId: 'free',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<User> signInWithGoogle() async {
    return mockUser ??
        User(
          id: 'google-user-id',
          fullName: 'Google User',
          email: 'google@foora.com',
          role: UserRole.member,
          membershipId: 'free',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetEmailSentTo = email;
  }

  @override
  Future<void> logout() async {
    isLoggedOut = true;
    mockUser = null;
  }
}

void main() {
  group('Auth Domain UseCases Test', () {
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
    });

    test(
      'LoginUseCase should return authenticated User upon success',
      () async {
        final loginUseCase = LoginUseCase(mockRepository);
        final user = await loginUseCase(
          email: 'test@foora.com',
          password: 'password123',
        );

        expect(user.email, 'test@foora.com');
        expect(user.role, UserRole.member);
        expect(user.isActive, true);
      },
    );

    test('RegisterUseCase should return newly created User', () async {
      final registerUseCase = RegisterUseCase(mockRepository);
      final user = await registerUseCase(
        fullName: 'Nguyễn Văn A',
        email: 'nguyenvana@foora.com',
        password: 'password123',
      );

      expect(user.id, 'new-user-id');
      expect(user.fullName, 'Nguyễn Văn A');
      expect(user.email, 'nguyenvana@foora.com');
    });

    test(
      'ResetPasswordUseCase should request password reset for given email',
      () async {
        final resetUseCase = ResetPasswordUseCase(mockRepository);
        await resetUseCase(email: 'reset@foora.com');

        expect(mockRepository.resetEmailSentTo, 'reset@foora.com');
      },
    );

    test('LogoutUseCase should invoke logout on repository', () async {
      final logoutUseCase = LogoutUseCase(mockRepository);
      await logoutUseCase();

      expect(mockRepository.isLoggedOut, true);
    });
  });

  group('InputValidators Unit Test', () {
    test('validateEmail checks valid and invalid emails', () {
      expect(InputValidators.validateEmail('user@foora.com'), isNull);
      expect(InputValidators.validateEmail(''), isNotNull);
      expect(InputValidators.validateEmail('invalid-email'), isNotNull);
      expect(InputValidators.validateEmail('user@domain'), isNotNull);
    });

    test('validatePassword checks minimum length', () {
      expect(InputValidators.validatePassword('123456'), isNull);
      expect(InputValidators.validatePassword('12345'), isNotNull);
      expect(InputValidators.validatePassword(''), isNotNull);
    });

    test('validateConfirmPassword checks matching password', () {
      expect(
        InputValidators.validateConfirmPassword('secret123', 'secret123'),
        isNull,
      );
      expect(
        InputValidators.validateConfirmPassword('secret123', 'secret999'),
        isNotNull,
      );
    });

    test('validateRequired checks required field', () {
      expect(InputValidators.validateRequired('John Doe', 'họ và tên'), isNull);
      expect(InputValidators.validateRequired('   ', 'họ và tên'), isNotNull);
      expect(InputValidators.validateRequired(null, 'họ và tên'), isNotNull);
    });
  });
}
