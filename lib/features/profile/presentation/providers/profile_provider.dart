import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/bug_report.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/change_password.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/submit_bug_report.dart';
import '../../domain/usecases/update_email.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/upload_avatar.dart';
import '../../domain/usecases/watch_profile.dart';

// --- Data Layer Providers ---

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
    storage: ref.watch(storageProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
  );
});

// --- UseCase Providers ---

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

final watchProfileUseCaseProvider = Provider<WatchProfileUseCase>((ref) {
  return WatchProfileUseCase(ref.watch(profileRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((ref) {
  return UploadAvatarUseCase(ref.watch(profileRepositoryProvider));
});

final updateEmailUseCaseProvider = Provider<UpdateEmailUseCase>((ref) {
  return UpdateEmailUseCase(ref.watch(profileRepositoryProvider));
});

final changePasswordUseCaseProvider = Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(ref.watch(profileRepositoryProvider));
});

final submitBugReportUseCaseProvider = Provider<SubmitBugReportUseCase>((ref) {
  return SubmitBugReportUseCase(ref.watch(profileRepositoryProvider));
});

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(profileRepositoryProvider));
});

// --- Stream Provider ---

/// Watches realtime Profile of the currently authenticated user
final currentProfileStreamProvider = StreamProvider<Profile?>((ref) {
  final authState = ref.watch(firebaseAuthProvider);
  final user = authState.currentUser;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(watchProfileUseCaseProvider).call(user.uid);
});

// --- Form & Action State Notifiers ---

/// UI state for edit-profile and account actions (loading, messages, avatar).
class EditProfileState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final String? successMessage;
  final String? selectedAvatarLocalPath;

  const EditProfileState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.successMessage,
    this.selectedAvatarLocalPath,
  });

  /// Returns a copy with the given fields replaced.
  EditProfileState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    String? successMessage,
    String? selectedAvatarLocalPath,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      selectedAvatarLocalPath:
          selectedAvatarLocalPath ?? this.selectedAvatarLocalPath,
    );
  }
}

/// Handles saving the profile, changing email/password and deleting the account.
class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final Ref _ref;

  EditProfileNotifier(this._ref) : super(const EditProfileState());

  /// Stores the locally picked avatar path (uploaded on save).
  void setAvatarLocalPath(String? path) {
    state = state.copyWith(selectedAvatarLocalPath: path);
  }

  /// Clears success / error messages.
  void clearMessages() {
    state = state.copyWith(
      clearError: true,
      clearSuccess: true,
      isSuccess: false,
    );
  }

  /// Uploads the new avatar if needed, then saves profile fields.
  Future<bool> saveProfile({
    required String userId,
    required String fullName,
    String? existingAvatarUrl,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      String? avatarUrl = existingAvatarUrl;
      // If user selected a new local image, upload it first
      if (state.selectedAvatarLocalPath != null) {
        avatarUrl = await _ref
            .read(uploadAvatarUseCaseProvider)
            .call(userId: userId, filePath: state.selectedAvatarLocalPath!);
      }

      await _ref
          .read(updateProfileUseCaseProvider)
          .call(userId: userId, fullName: fullName, avatarUrl: avatarUrl);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Cập nhật hồ sơ thành công.',
        selectedAvatarLocalPath: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Changes the email; returns `true` on success.
  Future<bool> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _ref
          .read(updateEmailUseCaseProvider)
          .call(newEmail: newEmail, currentPassword: currentPassword);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Cập nhật email thành công.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Changes the password; returns `true` on success.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _ref
          .read(changePasswordUseCaseProvider)
          .call(currentPassword: currentPassword, newPassword: newPassword);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Đổi mật khẩu thành công.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Deletes the account; returns `true` on success.
  Future<bool> deleteAccount({String? password}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _ref.read(deleteAccountUseCaseProvider).call(password: password);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Đã xóa tài khoản thành công.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final editProfileNotifierProvider =
    StateNotifierProvider<EditProfileNotifier, EditProfileState>((ref) {
      return EditProfileNotifier(ref);
    });

// --- Bug Report Notifier ---

/// UI state of the bug-report form.
class BugReportState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final String? successMessage;
  final String? selectedScreenshotPath;

  const BugReportState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.successMessage,
    this.selectedScreenshotPath,
  });

  /// Returns a copy with the given fields replaced.
  BugReportState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    String? successMessage,
    String? selectedScreenshotPath,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BugReportState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      selectedScreenshotPath:
          selectedScreenshotPath ?? this.selectedScreenshotPath,
    );
  }
}

/// Submits bug reports (with optional screenshot).
class BugReportNotifier extends StateNotifier<BugReportState> {
  final Ref _ref;

  BugReportNotifier(this._ref) : super(const BugReportState());

  /// Attaches or removes the screenshot.
  void setScreenshot(String? path) {
    state = state.copyWith(selectedScreenshotPath: path);
  }

  /// Resets the form state.
  void reset() {
    state = const BugReportState();
  }

  /// Sends the report; returns `true` on success.
  Future<bool> submitReport({
    required String userId,
    required String userEmail,
    required String category,
    required String title,
    required String description,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final report = BugReport(
        id: '',
        userId: userId,
        userEmail: userEmail,
        category: category,
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );

      await _ref
          .read(submitBugReportUseCaseProvider)
          .call(report, state.selectedScreenshotPath);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Cảm ơn bạn! Báo cáo sự cố đã được gửi thành công.',
        selectedScreenshotPath: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final bugReportNotifierProvider =
    StateNotifierProvider<BugReportNotifier, BugReportState>((ref) {
      return BugReportNotifier(ref);
    });
