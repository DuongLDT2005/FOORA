import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in_with_google.dart';

import '../../../notification/domain/usecases/register_device.dart';
import '../../../notification/domain/usecases/unregister_device.dart';
import '../../../notification/presentation/providers/notification_provider.dart';

// --- Data Layer Providers ---

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

// --- Domain Layer UseCase Providers ---

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final signInWithGoogleUseCaseProvider = Provider<SignInWithGoogleUseCase>((
  ref,
) {
  return SignInWithGoogleUseCase(ref.watch(authRepositoryProvider));
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

// --- Auth State Stream Provider ---

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Direct synchronous/async accessor for currently authenticated domain User
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.valueOrNull ?? ref.watch(authRepositoryProvider).currentUser;
});

/// Boolean provider indicating whether user is logged in
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// --- Presentation State Notifier ---

class AuthState {
  final bool isLoading;
  final User? user;
  final String? errorMessage;
  final bool isSuccess;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final SignInWithGoogleUseCase signInWithGoogleUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final LogoutUseCase logoutUseCase;
  final RegisterDeviceUseCase registerDeviceUseCase;
  final UnregisterDeviceUseCase unregisterDeviceUseCase;

  AuthNotifier({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.signInWithGoogleUseCase,
    required this.resetPasswordUseCase,
    required this.logoutUseCase,
    required this.registerDeviceUseCase,
    required this.unregisterDeviceUseCase,
  }) : super(const AuthState());

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final user = await loginUseCase(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user, isSuccess: true);
      registerDeviceUseCase(userId: user.id).catchError((_) => null);
      return true;
    } on Failure catch (f) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: f.message,
        isSuccess: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final user = await registerUseCase(
        fullName: fullName,
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user, isSuccess: true);
      registerDeviceUseCase(userId: user.id).catchError((_) => null);
      return true;
    } on Failure catch (f) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: f.message,
        isSuccess: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final user = await signInWithGoogleUseCase();
      state = state.copyWith(isLoading: false, user: user, isSuccess: true);
      registerDeviceUseCase(userId: user.id).catchError((_) => null);
      return true;
    } on Failure catch (f) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: f.message,
        isSuccess: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đăng nhập Google thất bại. Vui lòng thử lại.',
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      await resetPasswordUseCase(email: email);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on Failure catch (f) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: f.message,
        isSuccess: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
        isSuccess: false,
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final currentUid = state.user?.id;
      if (currentUid != null && currentUid.isNotEmpty) {
        await unregisterDeviceUseCase(userId: currentUid)
            .catchError((_) => null);
      }
      await logoutUseCase();
      state = const AuthState();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    signInWithGoogleUseCase: ref.watch(signInWithGoogleUseCaseProvider),
    resetPasswordUseCase: ref.watch(resetPasswordUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    registerDeviceUseCase: ref.watch(registerDeviceUseCaseProvider),
    unregisterDeviceUseCase: ref.watch(unregisterDeviceUseCaseProvider),
  );
});
